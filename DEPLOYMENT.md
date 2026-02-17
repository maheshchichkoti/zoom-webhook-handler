# EC2 Deployment Guide

## Server Info
- IP: 3.110.223.85
- User: ubuntu
- Key: tulkka-fastapi-key.pem

## Deployment Steps

### 1. SSH into Server
```bash
ssh -i tulkka-fastapi-key.pem ubuntu@3.110.223.85
```

### 2. Clone Repository
```bash
cd ~
git clone https://github.com/maheshchichkoti/zoom-webhook-handler.git
cd zoom-webhook-handler
```

### 3. Install Node.js (if not installed)
```bash
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
sudo apt-get install -y nodejs
node --version
npm --version
```

### 4. Install Dependencies
```bash
npm install
```

### 5. Configure Environment
```bash
cp .env.example .env
nano .env
```

Edit with your production values:
```env
PORT=3000
NODE_ENV=production

DB_HOST=localhost
DB_PORT=3306
DB_USER=tulkka_user
DB_PASSWORD=your_secure_password
DB_NAME=tulkka_local

ZOOM_WEBHOOK_SECRET=y89hMD-cQuy5r-yOoJz6IQ

LOG_LEVEL=info
```

### 6. Setup Database
```bash
mysql -u root -p tulkka_local < migrations/001_create_queue_table.sql
```

### 7. Install PM2
```bash
sudo npm install -g pm2
```

### 8. Start Service
```bash
pm2 start src/index.js --name zoom-webhook
pm2 save
pm2 startup
# Copy and run the command PM2 gives you
```

### 9. Configure Nginx (if needed)
```bash
sudo nano /etc/nginx/sites-available/zoom-webhook
```

Add:
```nginx
server {
    listen 80;
    server_name your-domain.com;

    location / {
        proxy_pass http://localhost:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_cache_bypass $http_upgrade;
    }
}
```

Enable:
```bash
sudo ln -s /etc/nginx/sites-available/zoom-webhook /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl reload nginx
```

### 10. Configure Firewall
```bash
sudo ufw allow 3000/tcp
sudo ufw status
```

## Useful Commands

### Check Service Status
```bash
pm2 status
pm2 logs zoom-webhook
```

### Restart Service
```bash
pm2 restart zoom-webhook
```

### Update Code
```bash
cd ~/zoom-webhook-handler
git pull origin main
npm install
pm2 restart zoom-webhook
```

### Check Database
```bash
mysql -u root -p tulkka_local -e "SELECT * FROM zoom_processing_queue ORDER BY created_at DESC LIMIT 5;"
```

### View Logs
```bash
pm2 logs zoom-webhook --lines 100
tail -f logs/combined.log
```

## Testing

### Test Health Endpoint
```bash
curl http://localhost:3000/health
```

### Test Webhook (from local machine)
```bash
curl -X POST http://3.110.223.85:3000/zoom/webhook \
  -H "Content-Type: application/json" \
  -d '{"event":"recording.completed","payload":{"object":{"id":123,"topic":"Test"}}}'
```

## Troubleshooting

### Service not starting?
```bash
pm2 logs zoom-webhook --err
```

### Database connection issues?
```bash
mysql -u tulkka_user -p tulkka_local
# Test connection
```

### Port already in use?
```bash
sudo lsof -i :3000
# Kill process if needed
```
