-- Create llm_intake_queue table (matches production schema)
CREATE TABLE IF NOT EXISTS `llm_intake_queue` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `audio_url` text NOT NULL COMMENT 'URL or path to the audio file',
  `level` varchar(50) DEFAULT 'unknown' COMMENT 'CEFR level hint',
  `language` varchar(50) DEFAULT 'hebrew' COMMENT 'Target language for analysis',
  `zoom_meeting_id` varchar(64) DEFAULT NULL COMMENT 'Zoom meeting ID if applicable',
  `topic` varchar(255) DEFAULT '' COMMENT 'Lesson topic hint',
  `idempotency_key` varchar(512) DEFAULT NULL COMMENT 'Dedup key; reuses existing llm_requests if matched',
  `priority` int DEFAULT '100' COMMENT 'Higher = admitted first',
  `status` varchar(32) DEFAULT 'PENDING' COMMENT 'PENDING | ADMITTING | ADMITTED | FAILED | CANCELLED | DISABLED',
  `request_id` char(36) DEFAULT NULL COMMENT 'FK to llm_requests.id once admitted',
  `attempt_count` int DEFAULT '0' COMMENT 'Number of admission attempts by intake module',
  `max_attempts` int DEFAULT '5' COMMENT 'Max attempts before auto-disable',
  `error` text COMMENT 'Last error message on failure',
  `metadata` json DEFAULT NULL COMMENT 'Arbitrary metadata from submitter',
  `created_at` datetime DEFAULT CURRENT_TIMESTAMP,
  `updated_at` datetime DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_intake_status_priority` (`status`,`priority` DESC,`created_at`),
  KEY `idx_intake_created_at` (`created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
