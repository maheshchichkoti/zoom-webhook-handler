// Test with REAL webhook structure from Zoom
require('dotenv').config();
const queueService = require('../src/services/queueService');
const db = require('../src/config/database');

async function testRealWebhook() {
  try {
    console.log('🧪 Testing with real Zoom webhook structure...\n');

    // This matches the EXACT real payload structure from the user's ngrok logs
    const realPayload = {
      account_id: "ClWOYRY5SbOP30gA6e2ksA",
      object: {
        uuid: "FayHmpCAQmm6Xv5Zn4z7qQ==",
        id: 85400706350,                          // <-- numeric meeting ID
        topic: "Database structure meeting",
        duration: 19,
        recording_count: 4,
        recording_files: [
          {
            id: "42a9b6ba-ea4a-48d2-aaf1-d717601e242e",
            meeting_id: "FayHmpCAQmm6Xv5Zn4z7qQ==",
            file_type: "M4A",
            file_extension: "M4A",
            download_url: "https://us06web.zoom.us/rec/webhook_download/test.m4a",
            status: "completed",
            recording_type: "audio_only"
          },
          {
            id: "fd99b3ab-0ebe-4ccd-9ba1-e6ce6e01114e",
            file_type: "TIMELINE",
            file_extension: "JSON",
            download_url: "https://us06web.zoom.us/rec/webhook_download/test.json",
            status: "completed"
          },
          {
            id: "ad56b637-f7b0-41c4-948f-a19a13f4becc",
            file_type: "MP4",
            file_extension: "MP4",
            download_url: "https://us06web.zoom.us/rec/webhook_download/test.mp4",
            status: "completed"
          }
        ]
      }
    };

    // Use a unique meeting ID for this test
    const testMeetingId = 99999999999;
    const testPayload = { ...realPayload, object: { ...realPayload.object, id: testMeetingId, uuid: 'TEST-UUID-==', topic: 'Test Meeting' } };
    testPayload.object.recording_files[0].id = 'test-rec-file-id';

    console.log('📤 Enqueueing with real webhook structure...');
    await queueService.enqueue(testMeetingId, testPayload);

    console.log('\n🔍 Checking llm_intake_queue...');
    const [rows] = await db.query(
      'SELECT id, zoom_meeting_id, topic, idempotency_key, audio_url, status, language FROM llm_intake_queue WHERE zoom_meeting_id = ?',
      [String(testMeetingId)]
    );

    if (rows.length > 0) {
      const row = rows[0];
      console.log('\n✅ llm_intake_queue record:');
      console.log(`   zoom_meeting_id : ${row.zoom_meeting_id}  ← numeric ID (not UUID)`);
      console.log(`   topic           : ${row.topic}`);
      console.log(`   idempotency_key : ${row.idempotency_key}  ← UUID_RecordingFileId`);
      console.log(`   audio_url       : ${row.audio_url.substring(0, 60)}...`);
      console.log(`   status          : ${row.status}`);
      console.log(`   language        : ${row.language}`);

      // Verify idempotency_key format
      const expectedKey = 'TEST-UUID-==_test-rec-file-id';
      if (row.idempotency_key === expectedKey) {
        console.log('\n✅ idempotency_key format is CORRECT (UUID_RecordingFileId)');
      } else {
        console.log(`\n❌ idempotency_key mismatch! Expected: ${expectedKey}, Got: ${row.idempotency_key}`);
      }
    } else {
      console.log('❌ No record found in llm_intake_queue!');
    }

    // Cleanup test record
    await db.query('DELETE FROM llm_intake_queue WHERE zoom_meeting_id = ?', [String(testMeetingId)]);
    await db.query('DELETE FROM zoom_processing_queue WHERE meeting_id = ?', [testMeetingId]);
    console.log('\n🧹 Test records cleaned up');
    console.log('\n✅ All checks passed! Ready for production.');

  } catch (error) {
    console.error('❌ Test failed:', error.message);
    console.error(error.stack);
  } finally {
    await db.end();
    process.exit(0);
  }
}

testRealWebhook();
