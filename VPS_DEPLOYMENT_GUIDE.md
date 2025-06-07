# Crypto Airdrop Platform - VPS Deployment Guide

## Overview
This guide will help you deploy your crypto airdrop learning platform to a VPS with production-ready configuration including SSL, process management, and database setup.

## Prerequisites
- Ubuntu 20.04+ VPS with minimum 2GB RAM
- Domain name pointed to your VPS IP
- Root or sudo access

## Step 1: Initial Server Setup

### Update System
```bash
sudo apt update && sudo apt upgrade -y
```

### Install Essential Dependencies
```bash
# Install Node.js 20.x
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt-get install -y nodejs

# Install PostgreSQL
sudo apt install postgresql postgresql-contrib -y

# Install Nginx
sudo apt install nginx -y

# Install PM2 for process management
sudo npm install -g pm2

# Install Git
sudo apt install git -y

# Install SSL tools
sudo apt install certbot python3-certbot-nginx -y
```

## Step 2: PostgreSQL Database Setup

### Create Database and User
```bash
# Switch to postgres user
sudo -u postgres psql

# Inside PostgreSQL shell, run:
CREATE DATABASE crypto_airdrop_db;
CREATE USER airdrop_user WITH ENCRYPTED PASSWORD 'your_secure_password_here';
GRANT ALL PRIVILEGES ON DATABASE crypto_airdrop_db TO airdrop_user;
ALTER USER airdrop_user CREATEDB;
\q
```

### Configure PostgreSQL for Remote Connections
```bash
# Edit PostgreSQL configuration
sudo nano /etc/postgresql/*/main/postgresql.conf

# Find and modify:
listen_addresses = 'localhost'

# Edit pg_hba.conf
sudo nano /etc/postgresql/*/main/pg_hba.conf

# Add this line for local connections:
local   all             airdrop_user                            md5

# Restart PostgreSQL
sudo systemctl restart postgresql
```

## Step 3: Deploy Application Code

### Create Application Directory
```bash
# Create app directory
sudo mkdir -p /var/www/crypto-airdrop
sudo chown $USER:$USER /var/www/crypto-airdrop
cd /var/www/crypto-airdrop

# Clone your repository (replace with your Git URL)
git clone https://github.com/yourusername/crypto-airdrop-platform.git .
```

### Install Dependencies
```bash
npm install
```

### Environment Configuration
```bash
# Create production environment file
nano .env.production

# Add the following variables:
NODE_ENV=production
DATABASE_URL=postgresql://airdrop_user:your_secure_password_here@localhost:5432/crypto_airdrop_db
SESSION_SECRET=your_very_long_random_session_secret_here_at_least_64_characters_long
PORT=5000

# For production, generate a strong session secret:
# node -e "console.log(require('crypto').randomBytes(64).toString('hex'))"
```

### Database Setup
```bash
# Push database schema
npm run db:push

# Seed initial data
npm run db:seed
```

### Build Application
```bash
# Build the frontend
npm run build
```

## Step 4: PM2 Process Management

### Create PM2 Configuration
```bash
nano ecosystem.config.js
```

Add this configuration:
```javascript
module.exports = {
  apps: [{
    name: 'crypto-airdrop-platform',
    script: 'tsx',
    args: 'server/index.ts',
    instances: 1,
    autorestart: true,
    watch: false,
    max_memory_restart: '1G',
    env: {
      NODE_ENV: 'development'
    },
    env_production: {
      NODE_ENV: 'production',
      PORT: 5000
    }
  }]
}
```

### Start Application with PM2
```bash
# Start the application
pm2 start ecosystem.config.js --env production

# Save PM2 configuration
pm2 save

# Enable PM2 startup script
pm2 startup
# Follow the instructions provided by the command above

# Check application status
pm2 status
pm2 logs crypto-airdrop-platform
```

## Step 5: Nginx Configuration

### Create Nginx Configuration
```bash
sudo nano /etc/nginx/sites-available/crypto-airdrop
```

Add this configuration (replace `yourdomain.com` with your actual domain):
```nginx
server {
    listen 80;
    server_name yourdomain.com www.yourdomain.com;

    # Redirect HTTP to HTTPS
    return 301 https://$server_name$request_uri;
}

server {
    listen 443 ssl http2;
    server_name yourdomain.com www.yourdomain.com;

    # SSL Configuration (will be added by Certbot)
    
    # Security Headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header Referrer-Policy "no-referrer-when-downgrade" always;
    add_header Content-Security-Policy "default-src 'self' http: https: data: blob: 'unsafe-inline'" always;

    # Gzip Compression
    gzip on;
    gzip_vary on;
    gzip_min_length 1024;
    gzip_proxied expired no-cache no-store private must-revalidate auth;
    gzip_types text/plain text/css text/xml text/javascript application/javascript application/xml+rss application/json;

    # Static Files
    location /assets/ {
        alias /var/www/crypto-airdrop/dist/client/assets/;
        expires 1y;
        add_header Cache-Control "public, immutable";
    }

    # WebSocket Support
    location /ws {
        proxy_pass http://localhost:5000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;
    }

    # API Routes
    location /api/ {
        proxy_pass http://localhost:5000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        
        # Enable CORS if needed
        add_header Access-Control-Allow-Origin "https://yourdomain.com" always;
        add_header Access-Control-Allow-Methods "GET, POST, PUT, DELETE, OPTIONS" always;
        add_header Access-Control-Allow-Headers "Authorization, Content-Type" always;
    }

    # Main Application
    location / {
        proxy_pass http://localhost:5000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    # File Upload Limit
    client_max_body_size 10M;
}
```

### Enable Site and Test Configuration
```bash
# Enable the site
sudo ln -s /etc/nginx/sites-available/crypto-airdrop /etc/nginx/sites-enabled/

# Remove default site
sudo rm /etc/nginx/sites-enabled/default

# Test Nginx configuration
sudo nginx -t

# Restart Nginx
sudo systemctl restart nginx
```

## Step 6: SSL Certificate Setup

### Install SSL Certificate with Let's Encrypt
```bash
# Obtain SSL certificate
sudo certbot --nginx -d yourdomain.com -d www.yourdomain.com

# Test automatic renewal
sudo certbot renew --dry-run
```

## Step 7: Firewall Configuration

### Configure UFW Firewall
```bash
# Enable UFW
sudo ufw enable

# Allow essential services
sudo ufw allow ssh
sudo ufw allow 'Nginx Full'
sudo ufw allow 5432  # PostgreSQL (if you need external access)

# Check status
sudo ufw status
```

## Step 8: Security Hardening

### Create Non-Root Application User
```bash
# Create dedicated user for the application
sudo adduser --system --group --home /var/www/crypto-airdrop airdrop

# Change ownership
sudo chown -R airdrop:airdrop /var/www/crypto-airdrop

# Update PM2 to run as airdrop user
sudo -u airdrop pm2 start ecosystem.config.js --env production
sudo -u airdrop pm2 save
```

### Database Security
```bash
# Secure PostgreSQL installation
sudo -u postgres psql -c "ALTER USER postgres PASSWORD 'very_secure_postgres_password';"

# Backup script
nano /home/airdrop/backup.sh
```

Add backup script:
```bash
#!/bin/bash
BACKUP_DIR="/var/backups/crypto-airdrop"
DATE=$(date +%Y%m%d_%H%M%S)

mkdir -p $BACKUP_DIR

# Database backup
pg_dump -h localhost -U airdrop_user crypto_airdrop_db > $BACKUP_DIR/db_backup_$DATE.sql

# Keep only last 7 days of backups
find $BACKUP_DIR -name "db_backup_*.sql" -mtime +7 -delete

echo "Backup completed: $DATE"
```

Make it executable and schedule:
```bash
chmod +x /home/airdrop/backup.sh

# Add to crontab (daily backup at 2 AM)
crontab -e
# Add: 0 2 * * * /home/airdrop/backup.sh
```

## Step 9: Monitoring and Logs

### Setup Log Rotation
```bash
sudo nano /etc/logrotate.d/crypto-airdrop
```

Add:
```
/var/www/crypto-airdrop/logs/*.log {
    daily
    missingok
    rotate 7
    compress
    delaycompress
    notifempty
    create 0644 airdrop airdrop
    postrotate
        pm2 reload crypto-airdrop-platform
    endscript
}
```

### Monitor Application
```bash
# Check application status
pm2 status
pm2 monit

# View logs
pm2 logs crypto-airdrop-platform

# Check Nginx logs
sudo tail -f /var/log/nginx/access.log
sudo tail -f /var/log/nginx/error.log

# Check system resources
htop
df -h
```

## Step 10: Domain and DNS Configuration

### DNS Records Required
Set these DNS records for your domain:

```
Type    Name    Value               TTL
A       @       YOUR_VPS_IP         3600
A       www     YOUR_VPS_IP         3600
CNAME   api     yourdomain.com      3600
```

## Step 11: Post-Deployment Tasks

### Create Admin Account
```bash
# Connect to your database
psql -h localhost -U airdrop_user -d crypto_airdrop_db

# Update your wallet address to admin
UPDATE users SET is_admin = true WHERE wallet_address = '0x14b66774d1eec557ff19dd637a0208a098c017be';
```

### Test Production Setup
1. Visit `https://yourdomain.com`
2. Test user registration/login
3. Test Web3 wallet connection
4. Test admin functionality
5. Test WebSocket chat functionality
6. Verify SSL certificate

## Step 12: Maintenance and Updates

### Application Updates
```bash
cd /var/www/crypto-airdrop

# Pull latest changes
git pull origin main

# Install new dependencies
npm install

# Run database migrations if any
npm run db:push

# Rebuild application
npm run build

# Restart application
pm2 restart crypto-airdrop-platform
```

### Database Maintenance
```bash
# Manual backup
pg_dump -h localhost -U airdrop_user crypto_airdrop_db > backup_$(date +%Y%m%d).sql

# Restore from backup
psql -h localhost -U airdrop_user -d crypto_airdrop_db < backup_file.sql
```

## Troubleshooting

### Common Issues

1. **Application won't start**
   ```bash
   pm2 logs crypto-airdrop-platform
   pm2 restart crypto-airdrop-platform
   ```

2. **Database connection issues**
   ```bash
   sudo systemctl status postgresql
   psql -h localhost -U airdrop_user -d crypto_airdrop_db
   ```

3. **Nginx configuration errors**
   ```bash
   sudo nginx -t
   sudo systemctl status nginx
   ```

4. **SSL certificate issues**
   ```bash
   sudo certbot certificates
   sudo certbot renew
   ```

5. **Check disk space**
   ```bash
   df -h
   sudo apt autoremove
   ```

## Performance Optimization

### Database Optimization
```sql
-- Add indexes for better performance
CREATE INDEX idx_airdrops_status ON airdrops(status);
CREATE INDEX idx_airdrops_category_id ON airdrops(category_id);
CREATE INDEX idx_users_wallet_address ON users(wallet_address);
```

### Node.js Optimization
Add to ecosystem.config.js:
```javascript
env_production: {
  NODE_ENV: 'production',
  PORT: 5000,
  NODE_OPTIONS: '--max-old-space-size=1024'
}
```

## Security Checklist

- [ ] Firewall configured and active
- [ ] SSL certificate installed and auto-renewal working
- [ ] Database user has limited privileges
- [ ] Application runs as non-root user
- [ ] Regular backups scheduled
- [ ] Log rotation configured
- [ ] Strong passwords used everywhere
- [ ] Session secret is secure and random
- [ ] CORS properly configured
- [ ] Security headers enabled in Nginx

## Support and Maintenance

Your crypto airdrop platform is now production-ready with:
- ✅ SSL encryption
- ✅ Process management with PM2
- ✅ Nginx reverse proxy
- ✅ PostgreSQL database
- ✅ Automated backups
- ✅ Security hardening
- ✅ Web3 wallet integration
- ✅ Real-time chat functionality
- ✅ Admin dashboard
- ✅ Role-based access control

For ongoing support, monitor the logs regularly and keep the system updated with security patches.