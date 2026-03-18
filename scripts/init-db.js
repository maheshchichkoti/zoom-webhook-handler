require('dotenv').config();

const db = require('../src/config/database');
const logger = require('../src/config/logger');

async function initDb() {
  logger.info('Initializing database schema for ngrokonline...');

  // 1) Ensure schema exists
  await db.query(`CREATE SCHEMA IF NOT EXISTS raw`);

  // 2) Ensure required table exists (minimal + compatible with existing code)
  await db.query(`
    CREATE TABLE IF NOT EXISTS raw.zoom_webhook_request (
      id bigserial PRIMARY KEY,
      source_id text NULL,
      idempotency_key text NOT NULL,
      meeting_id text NOT NULL,
      session_uuid text NULL,
      recording_start timestamptz NULL,
      recording_end timestamptz NULL,
      audio_url text NULL,
      urls text NULL,
      payload jsonb NULL,
      retry_count int4 NOT NULL DEFAULT 0,
      error_message text NULL,
      processed bool NOT NULL DEFAULT false,
      _etl_loaded_at timestamptz NOT NULL DEFAULT now(),
      started_at timestamptz NULL,
      completed_at timestamptz NULL,
      llm_response_raw jsonb NULL,
      created_at timestamptz NULL,
      webhook_payload jsonb NULL,
      transcript_s3_url text NULL,
      transcript_etag text NULL,
      CONSTRAINT uq_raw_zoom_session_uuid UNIQUE (session_uuid),
      CONSTRAINT uq_zoom_webhook_idempotency UNIQUE (idempotency_key)
    );
  `);

  // 3) Ensure indexes exist (idempotent)
  await db.query(`CREATE INDEX IF NOT EXISTS idx_raw_zoom_created ON raw.zoom_webhook_request (created_at)`);
  await db.query(`CREATE INDEX IF NOT EXISTS idx_raw_zoom_loaded ON raw.zoom_webhook_request (_etl_loaded_at)`);
  await db.query(`CREATE INDEX IF NOT EXISTS idx_raw_zoom_meeting ON raw.zoom_webhook_request (meeting_id)`);
  await db.query(`CREATE INDEX IF NOT EXISTS idx_raw_zoom_processed ON raw.zoom_webhook_request (processed, _etl_loaded_at)`);
  await db.query(`CREATE INDEX IF NOT EXISTS idx_raw_zoom_session ON raw.zoom_webhook_request (session_uuid)`);
  await db.query(`CREATE INDEX IF NOT EXISTS idx_zoom_recording_start ON raw.zoom_webhook_request (recording_start)`);

  logger.info('✅ Database initialized: raw.zoom_webhook_request is ready.');
}

initDb()
  .then(() => process.exit(0))
  .catch((err) => {
    logger.error(`❌ DB init failed: ${err.message}`, { stack: err.stack });
    process.exit(1);
  });

