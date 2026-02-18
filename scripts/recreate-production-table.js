// Drop and recreate llm_intake_queue with production schema
require('dotenv').config();
const mysql = require('mysql2/promise');

async function recreateTable() {
  const connection = await mysql.createConnection({
    host: process.env.DB_HOST,
    port: process.env.DB_PORT,
    user: process.env.DB_USER,
    password: process.env.DB_PASSWORD,
    database: process.env.DB_NAME
  });

  try {
    console.log('🗑️  Dropping existing llm_intake_queue table...');
    await connection.query('DROP TABLE IF EXISTS llm_intake_queue');
    console.log('✅ Table dropped');
    
    console.log('\n🔄 Creating llm_intake_queue with production schema...');
    await connection.query(`
      CREATE TABLE llm_intake_queue (
        id bigint NOT NULL AUTO_INCREMENT,
        audio_url text NOT NULL COMMENT 'URL or path to the audio file',
        level varchar(50) DEFAULT 'unknown' COMMENT 'CEFR level hint',
        language varchar(50) DEFAULT 'hebrew' COMMENT 'Target language for analysis',
        zoom_meeting_id varchar(64) DEFAULT NULL COMMENT 'Zoom meeting ID if applicable',
        topic varchar(255) DEFAULT '' COMMENT 'Lesson topic hint',
        idempotency_key varchar(512) DEFAULT NULL COMMENT 'Dedup key; reuses existing llm_requests if matched',
        priority int DEFAULT '100' COMMENT 'Higher = admitted first',
        status varchar(32) DEFAULT 'PENDING' COMMENT 'PENDING | ADMITTING | ADMITTED | FAILED | CANCELLED | DISABLED',
        request_id char(36) DEFAULT NULL COMMENT 'FK to llm_requests.id once admitted',
        attempt_count int DEFAULT '0' COMMENT 'Number of admission attempts by intake module',
        max_attempts int DEFAULT '5' COMMENT 'Max attempts before auto-disable',
        error text COMMENT 'Last error message on failure',
        metadata json DEFAULT NULL COMMENT 'Arbitrary metadata from submitter',
        created_at datetime DEFAULT CURRENT_TIMESTAMP,
        updated_at datetime DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        PRIMARY KEY (id),
        KEY idx_intake_status_priority (status,priority DESC,created_at),
        KEY idx_intake_created_at (created_at)
      ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci
    `);
    console.log('✅ Table created with production schema');
    
    // Verify
    const [columns] = await connection.query('DESCRIBE llm_intake_queue');
    console.log('\n📋 Production Schema Verified:');
    columns.forEach(col => {
      console.log(`  ✓ ${col.Field}: ${col.Type} ${col.Null === 'NO' ? 'NOT NULL' : 'NULL'} ${col.Default ? `DEFAULT ${col.Default}` : ''}`);
    });
    
  } catch (error) {
    console.error('❌ Error:', error.message);
    throw error;
  } finally {
    await connection.end();
  }
}

recreateTable().catch(console.error);
