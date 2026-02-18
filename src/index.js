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

// Test endpoint for webhook testing
app.post('/zoom/webhook/test', async (req, res) => {
  try {
    const payload = req.body;

    logger.info('='.repeat(60));
    logger.info('🧪 TEST WEBHOOK RECEIVED');
    logger.info('='.repeat(60));
    logger.info(`Event: ${payload.event || 'unknown'}`);
    logger.info(`Payload: ${JSON.stringify(payload, null, 2)}`);
    logger.info('='.repeat(60));

    res.json({
      status: 'test_received',
      message: 'Test webhook received successfully',
      receivedPayload: payload,
      timestamp: new Date().toISOString()
    });
  } catch (error) {
    logger.error('Test webhook error', { error: error.message });
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Zoom webhook endpoint - Simply saves to database
app.post('/zoom/webhook', async (req, res) => {
  try {
    const payload = req.body;

    logger.info('='.repeat(60));
    logger.info('📥 ZOOM WEBHOOK RECEIVED');
    logger.info('='.repeat(60));
    logger.info(`Event: ${payload.event}`);
    logger.info(`Meeting ID: ${payload.payload?.object?.id}`);
    logger.info(`Timestamp: ${new Date().toISOString()}`);
    logger.info('='.repeat(60));

    // Handle Zoom webhook validation
    if (payload.event === 'endpoint.url_validation') {
      const plainToken = payload.payload?.plainToken;
      if (plainToken) {
        const crypto = require('crypto');
        const encryptedToken = crypto
          .createHmac('sha256', process.env.ZOOM_WEBHOOK_SECRET || '')
          .update(plainToken)
          .digest('hex');

        logger.info('✅ Zoom webhook validation successful');
        logger.info(`Plain Token: ${plainToken}`);

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

      logger.info('📝 Processing recording.completed event');
      logger.info(`Meeting ID: ${meetingId}`);
      logger.info(`Topic: ${topic}`);
      logger.info(`Duration: ${meetingObj.duration} minutes`);
      logger.info(`Recording Files: ${meetingObj.recording_count}`);

      // Save only the payload object to database (not the entire webhook)
      await queueService.enqueue(meetingId, payload.payload);

      logger.info('✅ Event saved to database successfully');
      logger.info('='.repeat(60));

      return res.status(200).json({
        status: 'queued',
        meetingId,
        message: 'Recording queued for processing'
      });
    }

    // Acknowledge other events
    logger.info(`ℹ️  Event acknowledged (not processed): ${payload.event}`);
    logger.info('='.repeat(60));
    res.status(200).json({
      status: 'ok',
      event: payload.event,
      message: 'Event acknowledged but not processed'
    });

  } catch (error) {
    logger.error('='.repeat(60));
    logger.error('❌ ERROR HANDLING WEBHOOK');
    logger.error('='.repeat(60));
    logger.error(`Error: ${error.message}`);
    logger.error(`Stack: ${error.stack}`);
    logger.error('='.repeat(60));

    res.status(500).json({
      error: 'Internal server error',
      message: error.message
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
