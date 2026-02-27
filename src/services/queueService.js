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
      // Schema design:
      //   meeting_id   = numeric Zoom meeting ID (e.g. 5196898746) — for debugging & class lookup
      //   session_uuid = Zoom UUID (e.g. "dVt9GdiqQ...") — unique per recording session
      //
      // Why two columns?
      //   - meeting_id alone is NOT unique (teachers reuse Personal Room ID for every class)
      //   - session_uuid IS unique per class, AND same on Zoom webhook retries → perfect dedup key
      const sessionUuid = payload.object?.uuid || String(meetingId);

      // Extract meeting-level timestamps (accurate for the entire meeting)
      const meetingStartTime = payload.object?.start_time || null;
      const duration = payload.object?.duration || 0;

      // Calculate meeting end time from start_time + duration (in minutes)
      let meetingEndTime = null;
      if (meetingStartTime && duration) {
        const startDate = new Date(meetingStartTime);
        startDate.setMinutes(startDate.getMinutes() + duration);
        meetingEndTime = startDate.toISOString();
      }

      // Extract M4A audio URL
      const recordingFiles = payload.object?.recording_files || [];
      const m4aFile = recordingFiles.find(f => f.file_type === 'M4A');
      const audioUrl = m4aFile?.download_url || null;

      // Collect all download URLs as comma-separated string
      const allUrls = recordingFiles
        .map(f => f.download_url)
        .filter(url => url)
        .join(',');

      // Log extracted values for debugging
      logger.info(`📊 Extracted values for INSERT:`, {
        meetingStartTime,
        meetingEndTime,
        duration: `${duration} minutes`,
        audioUrl: audioUrl ? audioUrl.substring(0, 50) + '...' : null,
        urlsCount: allUrls ? allUrls.split(',').length : 0
      });

      const result = await db.query(
        `INSERT INTO raw.zoom_webhook_request
         (meeting_id, session_uuid, webhook_payload, source_id, idempotency_key, recording_start, recording_end, audio_url, urls, created_at)
         VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, NOW())
         ON CONFLICT (session_uuid)
         DO UPDATE SET
         webhook_payload = EXCLUDED.webhook_payload,
         recording_start = EXCLUDED.recording_start,
         recording_end = EXCLUDED.recording_end,
         audio_url = EXCLUDED.audio_url,
         urls = EXCLUDED.urls,
         retry_count = 0,
         error_message = NULL`,
        [meetingId, sessionUuid, payloadJson, null, sessionUuid, meetingStartTime, meetingEndTime, audioUrl, allUrls]
      );

      logger.info(`Job queued in raw.zoom_webhook_request: meeting_id=${meetingId}, session_uuid=${sessionUuid}, rows=${result.rowCount}`);




      // Step 2: Insert into llm_intake_queue (for lead's LLM app)
      // recordingFiles already declared above, reuse it

      if (m4aFile) {
        // Numeric meeting ID stored in zoom_meeting_id column (varchar 64)
        const numericMeetingId = String(payload.object?.id || meetingId);
        const sessionUuid = payload.object?.uuid || String(meetingId);
        const topic = payload.object?.topic || '';
        // idempotency_key = UUID_RecordingFileId (unique per session, matches lead's SQL)
        const idempotencyKey = `${sessionUuid}_${m4aFile.id}`;

        await db.query(
          `INSERT INTO raw.llm_intake_queue
           (audio_url, zoom_meeting_id, topic, idempotency_key, metadata, status, priority, language, source_id)
           VALUES ($1, $2, $3, $4, $5, 'PENDING', 100, 'hebrew', $6)
           ON CONFLICT (idempotency_key)
           DO UPDATE SET updated_at = CURRENT_TIMESTAMP`,
          [m4aFile.download_url, numericMeetingId, topic, idempotencyKey, payloadJson, null]
        );

        logger.info(`✅ llm_intake_queue: zoom_meeting_id=${numericMeetingId}, uuid=${sessionUuid}, topic="${topic}", idempotency_key=${idempotencyKey}`);
      } else {
        logger.warn(`⚠️  No M4A file found in recording_files for meeting_id=${meetingId}, skipping llm_intake_queue`);
      }

      return result.rowCount;
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
      const result = await db.query(
        `SELECT
           SUM(CASE WHEN started_at IS NULL AND error_message IS NULL THEN 1 ELSE 0 END) AS pending,
           SUM(CASE WHEN started_at IS NOT NULL AND completed_at IS NULL AND error_message IS NULL THEN 1 ELSE 0 END) AS processing,
           SUM(CASE WHEN completed_at IS NOT NULL AND error_message IS NULL THEN 1 ELSE 0 END) AS completed,
           SUM(CASE WHEN error_message IS NOT NULL THEN 1 ELSE 0 END) AS failed,
           COUNT(*) AS total
         FROM raw.zoom_webhook_request`
      );
      const rows = result.rows;

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
