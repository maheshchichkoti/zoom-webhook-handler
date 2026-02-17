# Quick Start Guide

## 1. Setup Database

```bash
mysql -u root -p tulkka_local < migrations/001_create_queue_table.sql
```

## 2. Start Service

```bash
npm start
```

## 3. Test Webhook

```bash
curl -X POST http://localhost:3000/zoom/webhook \
  -H "Content-Type: application/json" \
  -d '{
    "event": "recording.completed",
    "payload": {
      "object": {
        "uuid": "test-meeting-123",
        "topic": "Test Meeting"
      }
    }
  }'
```

## 4. Check Database

```bash
mysql -u root -p tulkka_local -e "SELECT * FROM zoom_processing_queue;"
```

## What This Service Does

✅ Receives Zoom webhooks  
✅ Saves them to database  
❌ Does NOT process recordings (your main backend handles that)

## Your Main Backend

Query the database to get events:

```javascript
const events = await db.query(
  "SELECT * FROM zoom_processing_queue WHERE status = 'pending'"
);
```
