const db = require('../config/database');
const logger = require('../config/logger');

class QueueService {
  /**
   * Add a new webhook payload to the processing queue
   * Inserts into both zoom_processing_queue and llm_intake_queue
   */
  async enqueue(meetingId, webhookPayload) {
    try {
      // Stringify the payload for storage
      const payloadJson = typeof webhookPayload === 'string'
        ? webhookPayload
        : JSON.stringify(webhookPayload);

      // Step 1: Insert into zoom_processing_queue (for ai-student-progress worker)
      // Production schema: id, meeting_id, webhook_payload, retry_count, error_message, created_at, started_at, completed_at, llm_response_raw
      // NOTE: No 'status' column in production!
      const [result] = await db.execute(
        `INSERT INTO zoom_processing_queue
         (meeting_id, webhook_payload)
         VALUES (?, ?)
         ON DUPLICATE KEY UPDATE
         webhook_payload = VALUES(webhook_payload),
         retry_count = 0,
         error_message = NULL`,
        [meetingId, payloadJson]
      );

      logger.info(`Job queued in zoom_processing_queue: meeting_id=${meetingId}, queueId=${result.insertId || 'updated'}`);

      // Step 2: Insert into llm_intake_queue (for lead's LLM app)
      const payload = typeof webhookPayload === 'string' ? JSON.parse(webhookPayload) : webhookPayload;
      const recordingFiles = payload.object?.recording_files || [];
      const m4aFile = recordingFiles.find(f => f.file_type === 'M4A');

      if (m4aFile) {
        // UUID is used for idempotency_key (matches lead's SQL: uuid + recording file id)
        const meetingUuid = payload.object?.uuid || String(meetingId);
        // Numeric meeting ID stored in zoom_meeting_id column (varchar 64)
        const numericMeetingId = String(payload.object?.id || meetingId);
        const topic = payload.object?.topic || '';
        // idempotency_key = UUID_RecordingFileId (exactly as lead's SQL does)
        const idempotencyKey = `${meetingUuid}_${m4aFile.id}`;

        await db.execute(
          `INSERT INTO llm_intake_queue
           (audio_url, zoom_meeting_id, topic, idempotency_key, metadata, status, priority, language)
           VALUES (?, ?, ?, ?, ?, 'PENDING', 100, 'hebrew')
           ON DUPLICATE KEY UPDATE updated_at = CURRENT_TIMESTAMP`,
          [m4aFile.download_url, numericMeetingId, topic, idempotencyKey, payloadJson]
        );

        logger.info(`✅ llm_intake_queue: zoom_meeting_id=${numericMeetingId}, uuid=${meetingUuid}, topic="${topic}", idempotency_key=${idempotencyKey}`);
      } else {
        logger.warn(`⚠️  No M4A file found in recording_files for meeting_id=${meetingId}, skipping llm_intake_queue`);
      }

      return result.insertId;
    } catch (error) {
      logger.error(`Failed to enqueue job: meeting_id=${meetingId}, error=${error.message}`);
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
      logger.error(`Failed to get queue stats: ${error.message}`);
      throw error;
    }
  }
}

module.exports = new QueueService();
