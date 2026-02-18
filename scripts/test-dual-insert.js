// Test dual-insert functionality
require('dotenv').config();
const queueService = require('../src/services/queueService');
const db = require('../src/config/database');

async function testDualInsert() {
  try {
    console.log('🧪 Testing dual-insert functionality...\n');
    
    // Sample Zoom webhook payload
    const testPayload = {
      event: 'recording.completed',
      payload: {
        object: {
          id: 'test-meeting-123',
          uuid: 'test-uuid-456',
          topic: 'Test English Lesson',
          duration: 45,
          recording_count: 1,
          recording_files: [
            {
              id: 'rec-file-789',
              file_type: 'M4A',
              file_extension: 'M4A',
              download_url: 'https://zoom.us/rec/download/test123.m4a',
              file_size: 15000000
            }
          ]
        }
      }
    };
    
    console.log('📤 Enqueueing test webhook...');
    await queueService.enqueue('test-meeting-123', testPayload.payload);
    
    console.log('\n✅ Enqueue completed! Checking both tables...\n');
    
    // Check zoom_processing_queue
    const [zoomQueue] = await db.query(
      'SELECT * FROM zoom_processing_queue WHERE meeting_id = ?',
      ['test-meeting-123']
    );
    
    console.log('📋 zoom_processing_queue:');
    if (zoomQueue.length > 0) {
      console.log('  ✅ Record found');
      console.log(`     meeting_id: ${zoomQueue[0].meeting_id}`);
      console.log(`     status: ${zoomQueue[0].status}`);
    } else {
      console.log('  ❌ No record found');
    }
    
    // Check llm_intake_queue
    const [llmQueue] = await db.query(
      'SELECT * FROM llm_intake_queue WHERE zoom_meeting_id = ?',
      ['test-uuid-456']
    );
    
    console.log('\n📋 llm_intake_queue:');
    if (llmQueue.length > 0) {
      console.log('  ✅ Record found');
      console.log(`     zoom_meeting_id: ${llmQueue[0].zoom_meeting_id}`);
      console.log(`     topic: ${llmQueue[0].topic}`);
      console.log(`     audio_url: ${llmQueue[0].audio_url.substring(0, 50)}...`);
      console.log(`     idempotency_key: ${llmQueue[0].idempotency_key}`);
      console.log(`     status: ${llmQueue[0].status}`);
      console.log(`     language: ${llmQueue[0].language}`);
    } else {
      console.log('  ❌ No record found');
    }
    
    console.log('\n✅ Test completed successfully!');
    
  } catch (error) {
    console.error('❌ Test failed:', error.message);
    console.error(error.stack);
  } finally {
    await db.end();
    process.exit(0);
  }
}

testDualInsert();
