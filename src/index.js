require('dotenv').config();
const express = require('express');
const logger = require('./config/logger');
const queueService = require('./services/queueService');

const app = express();
const PORT = process.env.PORT || 3000;

// Middleware
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true }));

// Request logging middleware
app.use((req, res, next) => {
  const start = Date.now();
  res.on('finish', () => {
    const duration = Date.now() - start;
    logger.info('HTTP Request', {
      method: req.method,
      path: req.path,
      status: res.statusCode,
      duration: `${duration}ms`
    });
  });
  next();
});

// Health check endpoint
app.get('/health', (req, res) => {
  res.json({ 
    status: 'ok', 
    service: 'zoom-webhook-receiver',
    timestamp: new Date().toISOString(),
    uptime: process.uptime()
  });
});

// Zoom webhook endpoint - Simply saves to database
app.post('/zoom/webhook', async (req, res) => {
  try {
    const payload = req.body;
    
    logger.info('Received Zoom webhook', { 
      event: payload.event,
      meetingId: payload.payload?.object?.id
    });

    // Handle Zoom webhook validation
    if (payload.event === 'endpoint.url_validation') {
      const plainToken = payload.payload?.plainToken;
      if (plainToken) {
        const crypto = require('crypto');
        const encryptedToken = crypto
          .createHmac('sha256', process.env.ZOOM_WEBHOOK_SECRET || '')
          .update(plainToken)
          .digest('hex');
        
        logger.info('Zoom webhook validation', { plainToken });
        
        return res.status(200).json({
          plainToken,
          encryptedToken
        });
      }
    }

    // Save recording.completed events to database
    if (payload.event === 'recording.completed') {
      const meetingObj = payload.payload.object;
      const meetingId = meetingObj.id; // Use numeric ID, not UUID
      const topic = meetingObj.topic;
      
      // Save only the payload object to database (not the entire webhook)
      await queueService.enqueue(meetingId, payload.payload);
      
      logger.info('Event saved to database', { 
        meetingId, 
        topic,
        duration: meetingObj.duration,
        recordingCount: meetingObj.recording_count
      });
      
      return res.status(200).json({ 
        status: 'queued'
      });
    }

    // Acknowledge other events
    logger.info('Event acknowledged', { event: payload.event });
    res.status(200).json({ status: 'ok' });
    
  } catch (error) {
    logger.error('Error handling webhook', { 
      error: error.message, 
      stack: error.stack 
    });
    res.status(500).json({ 
      error: 'Internal server error'
    });
  }
});

// Queue stats endpoint
app.get('/queue/stats', async (req, res) => {
  try {
    const stats = await queueService.getStats();
    res.json({
      success: true,
      stats,
      timestamp: new Date().toISOString()
    });
  } catch (error) {
    logger.error('Error getting queue stats', { error: error.message });
    res.status(500).json({ error: 'Internal server error' });
  }
});

// 404 handler
app.use((req, res) => {
  res.status(404).json({ error: 'Not found' });
});

// Error handling middleware
app.use((err, req, res, next) => {
  logger.error('Unhandled error', { 
    error: err.message, 
    stack: err.stack
  });
  res.status(500).json({ error: 'Internal server error' });
});

// Start server
const server = app.listen(PORT, () => {
  logger.info('='.repeat(50));
  logger.info('Zoom Webhook Receiver Started');
  logger.info('='.repeat(50));
  logger.info(`Port: ${PORT}`);
  logger.info(`Environment: ${process.env.NODE_ENV || 'development'}`);
  logger.info(`Database: ${process.env.DB_HOST}/${process.env.DB_NAME}`);
  logger.info('Purpose: Save Zoom events to database');
  logger.info('='.repeat(50));
});

// Graceful shutdown
const shutdown = (signal) => {
  logger.info(`${signal} received, shutting down`);
  server.close(() => {
    logger.info('Server closed');
    process.exit(0);
  });
};

process.on('SIGTERM', () => shutdown('SIGTERM'));
process.on('SIGINT', () => shutdown('SIGINT'));

module.exports = app;
