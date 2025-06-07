# VPS PostgreSQL Setup Guide for Crypto Airdrop Platform

## Prerequisites
- Ubuntu/Debian VPS with root access
- Domain name pointing to your VPS IP (optional but recommended)

## Step 1: System Updates and PostgreSQL Installation

```bash
# Update system packages
sudo apt update && sudo apt upgrade -y

# Install PostgreSQL and required dependencies
sudo apt install postgresql postgresql-contrib nodejs npm git nginx certbot python3-certbot-nginx -y

# Install PM2 globally for process management
sudo npm install -g pm2
```

## Step 2: PostgreSQL Database Configuration

### Create Database and User
```bash
# Switch to postgres user
sudo -u postgres psql

# In PostgreSQL prompt, create database and user:
CREATE DATABASE crypto_airdrop_db;
CREATE USER airdrop_user WITH PASSWORD 'your_secure_password_here';
GRANT ALL PRIVILEGES ON DATABASE crypto_airdrop_db TO airdrop_user;
GRANT ALL ON SCHEMA public TO airdrop_user;
ALTER USER airdrop_user CREATEDB;
\q
```

### Configure PostgreSQL Authentication
```bash
# Edit PostgreSQL configuration
sudo nano /etc/postgresql/*/main/pg_hba.conf

# Add this line for local connections (replace * with your PostgreSQL version):
local   crypto_airdrop_db    airdrop_user                     md5

# Edit PostgreSQL main config
sudo nano /etc/postgresql/*/main/postgresql.conf

# Uncomment and modify these lines:
listen_addresses = 'localhost'
port = 5432

# Restart PostgreSQL
sudo systemctl restart postgresql
sudo systemctl enable postgresql
```

## Step 3: Application Deployment

### Create Application Directory
```bash
# Create app directory
sudo mkdir -p /var/www/crypto-airdrop
sudo chown $USER:$USER /var/www/crypto-airdrop
cd /var/www/crypto-airdrop

# Clone your repository
git clone <your-repo-url> .
# OR upload your files via SCP/SFTP
```

### Install Dependencies and Build
```bash
# Install Node.js dependencies
npm install

# Create production environment file
nano .env.production
```

### Environment Configuration (.env.production)
```env
NODE_ENV=production
DATABASE_URL=postgresql://airdrop_user:your_secure_password_here@localhost:5432/crypto_airdrop_db
SESSION_SECRET=your_very_long_random_session_secret_here_at_least_64_characters_long
PORT=5000

# Generate a strong session secret with:
# node -e "console.log(require('crypto').randomBytes(64).toString('hex'))"
```

### Database Schema and Seeding
```bash
# Set environment for production
export NODE_ENV=production

# Push database schema (creates all tables)
npm run db:push

# Seed initial data (creates admin user and sample data)
npm run db:seed

# Build the frontend
npm run build
```

## Step 4: PM2 Process Management

### Create PM2 Ecosystem File
```bash
# Create ecosystem.config.js
cat > ecosystem.config.js << 'EOF'
module.exports = {
  apps: [{
    name: 'crypto-airdrop-platform',
    script: 'tsx',
    args: 'server/index.ts',
    instances: 1,
    autorestart: true,
    watch: false,
    max_memory_restart: '1G',
    env_file: '.env.production',
    env: {
      NODE_ENV: 'production',
      PORT: 5000
    }
  }]
}
EOF
```

### Start Application
```bash
# Start the application
pm2 start ecosystem.config.js

# Save PM2 configuration
pm2 save

# Setup PM2 to start on system boot
pm2 startup
# Run the command that PM2 outputs

# Check application status
pm2 status
pm2 logs crypto-airdrop-platform
```

## Step 5: Nginx Reverse Proxy Configuration

### Create Nginx Site Configuration
```bash
sudo nano /etc/nginx/sites-available/crypto-airdrop
```

```nginx
server {
    listen 80;
    server_name your-domain.com www.your-domain.com;

    location / {
        proxy_pass http://localhost:5000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;
    }

    # WebSocket support for chat functionality
    location /ws {
        proxy_pass http://localhost:5000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header Referrer-Policy "no-referrer-when-downgrade" always;
    add_header Content-Security-Policy "default-src 'self' http: https: data: blob: 'unsafe-inline'" always;
}
```

### Enable Site and Test
```bash
# Enable the site
sudo ln -s /etc/nginx/sites-available/crypto-airdrop /etc/nginx/sites-enabled/

# Remove default site
sudo rm -f /etc/nginx/sites-enabled/default

# Test configuration
sudo nginx -t

# Restart Nginx
sudo systemctl restart nginx
sudo systemctl enable nginx
```

## Step 6: SSL Certificate (Optional but Recommended)

```bash
# Install SSL certificate with Let's Encrypt
sudo certbot --nginx -d your-domain.com -d www.your-domain.com

# Test automatic renewal
sudo certbot renew --dry-run
```

## Step 7: Firewall Configuration

```bash
# Enable UFW firewall
sudo ufw enable

# Allow essential services
sudo ufw allow ssh
sudo ufw allow 'Nginx Full'
sudo ufw allow 22/tcp
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp

# Check firewall status
sudo ufw status
```

## Step 8: Application Verification

### Test Database Connection
```bash
# Test database connection
sudo -u postgres psql -d crypto_airdrop_db -U airdrop_user -h localhost

# Check tables were created
\dt

# Check sample data
SELECT * FROM users LIMIT 5;
SELECT * FROM categories;
\q
```

### Test Application
```bash
# Check application logs
pm2 logs crypto-airdrop-platform

# Test application endpoint
curl http://localhost:5000/api/categories
curl http://your-domain.com/api/categories
```

## Default Login Credentials

After successful deployment, you can log in with:
- **Admin User**: username `admin`, password `admin123`
- **Demo User**: username `demo`, password `demo123`

**Important**: Change these default passwords immediately after first login!

## Maintenance Commands

```bash
# View application logs
pm2 logs crypto-airdrop-platform

# Restart application
pm2 restart crypto-airdrop-platform

# Update application
cd /var/www/crypto-airdrop
git pull
npm install
npm run build
pm2 restart crypto-airdrop-platform

# Database backup
pg_dump -U airdrop_user -h localhost crypto_airdrop_db > backup_$(date +%Y%m%d_%H%M%S).sql

# Restore database
psql -U airdrop_user -h localhost crypto_airdrop_db < backup_file.sql
```

## Troubleshooting

### Common Issues

1. **Database connection errors**:
   ```bash
   # Check PostgreSQL status
   sudo systemctl status postgresql
   
   # Check if user can connect
   sudo -u postgres psql -d crypto_airdrop_db -U airdrop_user
   ```

2. **Application won't start**:
   ```bash
   # Check detailed logs
   pm2 logs crypto-airdrop-platform --lines 50
   
   # Check environment variables
   pm2 env crypto-airdrop-platform
   ```

3. **Nginx configuration issues**:
   ```bash
   # Test Nginx config
   sudo nginx -t
   
   # Check Nginx logs
   sudo tail -f /var/log/nginx/error.log
   ```

4. **Port already in use**:
   ```bash
   # Check what's using port 5000
   sudo lsof -i :5000
   
   # Kill process if needed
   sudo kill -9 <PID>
   ```

## Security Recommendations

1. Change default passwords immediately
2. Use strong database passwords
3. Keep system updated: `sudo apt update && sudo apt upgrade`
4. Monitor logs regularly: `pm2 monit`
5. Setup automated backups
6. Use fail2ban for additional security:
   ```bash
   sudo apt install fail2ban
   sudo systemctl enable fail2ban
   ```

This setup provides a production-ready deployment of your crypto airdrop platform with PostgreSQL database, proper process management, and secure reverse proxy configuration.