-- ============================================================
-- Migration: Add session_uuid to zoom_processing_queue
-- Run this on the LIVE database (tulkka_live)
-- ============================================================

-- Step 1: Drop old UNIQUE KEY on numeric meeting_id
-- (meeting_id is NOT unique — teachers reuse Personal Room ID for every class)
ALTER TABLE zoom_processing_queue DROP INDEX unique_meeting;

-- Step 2: Add session_uuid column (Zoom's UUID — unique per recording session)
-- and add UNIQUE constraint on it
ALTER TABLE zoom_processing_queue
ADD COLUMN session_uuid VARCHAR(100) NULL AFTER meeting_id,
ADD UNIQUE KEY unique_session_uuid (session_uuid);

-- ============================================================
-- Verify the result:
-- ============================================================
-- DESCRIBE zoom_processing_queue;
-- SHOW INDEX FROM zoom_processing_queue;
--
-- Expected columns after migration:
--   id, meeting_id, session_uuid, webhook_payload, retry_count,
--   error_message, created_at, started_at, completed_at, llm_response_raw
--
-- Expected indexes:
--   PRIMARY KEY (id)
--   UNIQUE KEY unique_session_uuid (session_uuid)   ← new
--   KEY idx_meeting_id (meeting_id)
--   KEY idx_created_at (created_at)
-- ============================================================
