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
      
      logger.info('Job queued', { meetingId, queueId: result.insertId || 'updated' });
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
