const db = require('../config/database');
const logger = require('../config/logger');

class QueueService {
  /**
   * Add a new webhook payload to the processing queue
   * Matches ai-student-progress format exactly
   */
  async enqueue(meetingId, webhookPayload) {
    try {
      // Stringify the payload for storage (same as ai-student-progress)
      const payloadJson = typeof webhookPayload === 'string' 
        ? webhookPayload 
        : JSON.stringify(webhookPayload);
      
      // Step 1: Insert into zoom_processing_queue
      const [result] = await db.execute(
        `INSERT INTO zoom_processing_queue 
         (meeting_id, webhook_payload, status, created_at) 
         VALUES (?, ?, 'pending', NOW())
         ON DUPLICATE KEY UPDATE 
         webhook_payload = VALUES(webhook_payload),
         status = 'pending',
         retry_count = 0,
         error_message = NULL`,
        [meetingId, payloadJson]
      );
      
      logger.info('Job queued in zoom_processing_queue', { meetingId, queueId: result.insertId || 'updated' });
      
      // Step 2: Insert into llm_intake_queue (for user's app)
      // Extract M4A file info from payload
      const payload = typeof webhookPayload === 'string' ? JSON.parse(webhookPayload) : webhookPayload;
      const recordingFiles = payload.object?.recording_files || [];
      const m4aFile = recordingFiles.find(f => f.file_type === 'M4A');
      
      if (m4aFile) {
        const meetingUuid = payload.object?.uuid || meetingId;
        const topic = payload.object?.topic || 'Untitled Meeting';
        const idempotencyKey = `${meetingUuid}_${m4aFile.id}`;
        
        await db.execute(
          `INSERT INTO llm_intake_queue 
           (audio_url, zoom_meeting_id, topic, idempotency_key, metadata, status, priority, language)
           VALUES (?, ?, ?, ?, ?, 'PENDING', 100, 'hebrew')
           ON DUPLICATE KEY UPDATE updated_at = CURRENT_TIMESTAMP`,
          [m4aFile.download_url, meetingUuid, topic, idempotencyKey, payloadJson]
        );
        
        logger.info('Job queued in llm_intake_queue', { meetingId, idempotencyKey });
      } else {
        logger.warn('No M4A file found in recording, skipping llm_intake_queue', { meetingId });
      }
      
      return result.insertId;
    } catch (error) {
      logger.error('Failed to enqueue job', { meetingId, error: error.message });
      throw error;
    }
  }

  /**
   * Get queue statistics
   */
  async getStats() {
    try {
      const [rows] = await db.execute(
        `SELECT status, COUNT(*) as count
         FROM zoom_processing_queue 
         GROUP BY status`
      );
      
      const stats = { pending: 0, processing: 0, completed: 0, failed: 0 };
      rows.forEach(row => {
        stats[row.status] = parseInt(row.count);
      });
      stats.total = Object.values(stats).reduce((sum, count) => sum + count, 0);
      
      return stats;
    } catch (error) {
      logger.error('Failed to get queue stats', { error: error.message });
      throw error;
    }
  }
}

module.exports = new QueueService();
