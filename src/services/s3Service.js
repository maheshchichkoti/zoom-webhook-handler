const { S3Client, PutObjectCommand } = require('@aws-sdk/client-s3');
const axios = require('axios');
const logger = require('../config/logger');

const REGION = process.env.AWS_REGION || process.env.AWS_DEFAULT_REGION || 'us-east-1';
const TRANSCRIPT_BUCKET_NAME = process.env.TRANSCRIPT_BUCKET_NAME;

// Uses explicit credentials if provided; otherwise falls back to
// default AWS SDK resolution (env vars, IAM role, etc.).
const s3Client = new S3Client({
  region: REGION,
  credentials: process.env.AWS_ACCESS_KEY_ID && process.env.AWS_SECRET_ACCESS_KEY
    ? {
        accessKeyId: process.env.AWS_ACCESS_KEY_ID,
        secretAccessKey: process.env.AWS_SECRET_ACCESS_KEY,
      }
    : undefined,
});

function buildTranscriptKey({ meetingId, sessionUuid, meetingStartTime, recordingId }) {
  const date = meetingStartTime ? new Date(meetingStartTime) : new Date();
  const year = date.getUTCFullYear();
  const month = String(date.getUTCMonth() + 1).padStart(2, '0');
  const day = String(date.getUTCDate()).padStart(2, '0');
  const weekday = date.toLocaleDateString('en-US', { weekday: 'short', timeZone: 'UTC' });

  // Example structure:
  // 2026/03/16/Mon/meeting-4623974658/timeline-c7fc5c21-....json
  return `${year}/${month}/${day}/${weekday}/meeting-${meetingId}/timeline-${recordingId}.json`;
}

async function uploadZoomTimelineToS3({ meetingId, sessionUuid, meetingStartTime, timelineFile }) {
  if (!TRANSCRIPT_BUCKET_NAME) {
    logger.warn('TRANSCRIPT_BUCKET_NAME not set, skipping transcript upload to S3');
    return null;
  }

  if (!timelineFile?.download_url) {
    logger.warn('No download_url for timeline file, skipping transcript upload');
    return null;
  }

  const key = buildTranscriptKey({
    meetingId,
    sessionUuid,
    meetingStartTime,
    recordingId: timelineFile.id,
  });

  logger.info('⬇️  Downloading Zoom timeline JSON', {
    meetingId,
    sessionUuid,
    recordingId: timelineFile.id,
  });

  const response = await axios.get(timelineFile.download_url, {
    responseType: 'arraybuffer',
    timeout: 30_000,
  });

  const body = response.data;

  logger.info('⬆️  Uploading transcript to S3', {
    bucket: TRANSCRIPT_BUCKET_NAME,
    key,
    bytes: body.byteLength || body.length || null,
  });

  const putCommand = new PutObjectCommand({
    Bucket: TRANSCRIPT_BUCKET_NAME,
    Key: key,
    Body: body,
    ContentType: 'application/json',
  });

  const result = await s3Client.send(putCommand);

  const etag = result.ETag ? result.ETag.replace(/"/g, '') : null;
  const url = `https://${TRANSCRIPT_BUCKET_NAME}.s3.${REGION}.amazonaws.com/${encodeURI(key)}`;

  logger.info('✅ Transcript uploaded to S3', {
    bucket: TRANSCRIPT_BUCKET_NAME,
    key,
    etag,
    url,
  });

  return {
    bucket: TRANSCRIPT_BUCKET_NAME,
    key,
    etag,
    url,
    meetingId,
    sessionUuid,
    recordingId: timelineFile.id,
  };
}

module.exports = {
  uploadZoomTimelineToS3,
};

