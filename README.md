# Zoom Webhook Handler

Simple, production-ready service to receive Zoom recording webhooks and save them to MySQL database.

## Features

- ✅ Receives Zoom `recording.completed` webhooks
- ✅ Saves to MySQL database queue
- ✅ Production-ready with logging and error handling
- ✅ Compatible with ai-student-progress backend

## Quick Start

### 1. Install Dependencies
```bash
npm install
```

### 2. Configure Environment
```bash
cp .env.example .env
# Edit .env with your database credentials
```

### 3. Setup Database
```bash
mysql -u root -p your_database < migrations/001_create_queue_table.sql
```

### 4. Start Service
```bash
npm start
```

## Environment Variables

```env
PORT=3000
NODE_ENV=production

DB_HOST=localhost
DB_PORT=3306
DB_USER=your_db_user
DB_PASSWORD=your_db_password
DB_NAME=your_database

ZOOM_WEBHOOK_SECRET=your_zoom_secret

LOG_LEVEL=info
```

## API Endpoints

- `POST /zoom/webhook` - Receive Zoom webhooks
- `GET /health` - Health check
- `GET /queue/stats` - Queue statistics

## Deployment

### PM2 (Recommended)
```bash
npm install -g pm2
pm2 start src/index.js --name zoom-webhook
pm2 save
pm2 startup
```

### Manual
```bash
npm start
```

## Database Schema

Table: `zoom_processing_queue`
- Stores webhook payloads as JSON
- Status: pending, processing, completed, failed
- Automatic duplicate handling

## License

ISC
