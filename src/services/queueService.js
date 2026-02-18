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

      // Parse payload once, reuse below
      const payload = typeof webhookPayload === 'string' ? JSON.parse(webhookPayload) : webhookPayload;

      // Step 1: Insert into zoom_processing_queue (for ai-student-progress worker)
      //
      // NOTE: zoom_processing_queue.unique_meeting UNIQUE KEY has been dropped on live DB.
      // Each recording session gets its own row. Numeric meeting_id kept for easy debugging.
      const [result] = await db.execute(
        `INSERT INTO zoom_processing_queue
         (meeting_id, webhook_payload)
         VALUES (?, ?)`,
        [meetingId, payloadJson]
      );

      logger.info(`Job queued in zoom_processing_queue: meeting_id=${meetingId}, queueId=${result.insertId}`);

      // Step 2: Insert into llm_intake_queue (for lead's LLM app)
      const recordingFiles = payload.object?.recording_files || [];
      const m4aFile = recordingFiles.find(f => f.file_type === 'M4A');

      if (m4aFile) {
        // Numeric meeting ID stored in zoom_meeting_id column (varchar 64)
        const numericMeetingId = String(payload.object?.id || meetingId);
        const sessionUuid = payload.object?.uuid || String(meetingId);
        const topic = payload.object?.topic || '';
        // idempotency_key = UUID_RecordingFileId (unique per session, matches lead's SQL)
        const idempotencyKey = `${sessionUuid}_${m4aFile.id}`;

        await db.execute(
          `INSERT INTO llm_intake_queue
           (audio_url, zoom_meeting_id, topic, idempotency_key, metadata, status, priority, language)
           VALUES (?, ?, ?, ?, ?, 'PENDING', 100, 'hebrew')
           ON DUPLICATE KEY UPDATE updated_at = CURRENT_TIMESTAMP`,
          [m4aFile.download_url, numericMeetingId, topic, idempotencyKey, payloadJson]
        );

        logger.info(`✅ llm_intake_queue: zoom_meeting_id=${numericMeetingId}, uuid=${sessionUuid}, topic="${topic}", idempotency_key=${idempotencyKey}`);
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
        `SELECT
           SUM(started_at IS NULL AND error_message IS NULL) AS pending,
           SUM(started_at IS NOT NULL AND completed_at IS NULL AND error_message IS NULL) AS processing,
           SUM(completed_at IS NOT NULL AND error_message IS NULL) AS completed,
           SUM(error_message IS NOT NULL) AS failed,
           COUNT(*) AS total
         FROM zoom_processing_queue`
      );

      return {
        pending:    Number(rows[0]?.pending    || 0),
        processing: Number(rows[0]?.processing || 0),
        completed:  Number(rows[0]?.completed  || 0),
        failed:     Number(rows[0]?.failed     || 0),
        total:      Number(rows[0]?.total      || 0)
      };
    } catch (error) {
      logger.error(`Failed to get queue stats: ${error.message}`);
      throw error;
    }
  }
}

module.exports = new QueueService();
