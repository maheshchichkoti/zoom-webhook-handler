// Run migration to create llm_intake_queue table
require('dotenv').config();
const mysql = require('mysql2/promise');
const fs = require('fs');
const path = require('path');

async function runMigration() {
  const connection = await mysql.createConnection({
    host: process.env.DB_HOST,
    port: process.env.DB_PORT,
    user: process.env.DB_USER,
    password: process.env.DB_PASSWORD,
    database: process.env.DB_NAME
  });

  try {
    console.log('🔄 Running migration: 002_create_llm_intake_queue.sql');
    
    const sql = fs.readFileSync(
      path.join(__dirname, '../migrations/002_create_llm_intake_queue.sql'),
      'utf8'
    );
    
    await connection.query(sql);
    console.log('✅ Migration completed successfully');
    
    // Verify table was created
    const [tables] = await connection.query("SHOW TABLES LIKE 'llm_intake_queue'");
    if (tables.length > 0) {
      console.log('✅ Table llm_intake_queue exists');
      
      // Show table structure
      const [columns] = await connection.query('DESCRIBE llm_intake_queue');
      console.log('\n📋 Table structure:');
      columns.forEach(col => {
        console.log(`  - ${col.Field}: ${col.Type} ${col.Null === 'NO' ? 'NOT NULL' : ''}`);
      });
    }
    
  } catch (error) {
    console.error('❌ Migration failed:', error.message);
    throw error;
  } finally {
    await connection.end();
  }
}

runMigration().catch(console.error);
