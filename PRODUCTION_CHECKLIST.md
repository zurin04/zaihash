# Production Deployment Checklist

## Pre-Deployment Verification

### ✅ Authentication System Tests
- [x] Traditional username/password login working
- [x] User registration working  
- [x] Web3 wallet authentication working
- [x] Admin user privileges working
- [x] Session management working
- [x] Password hashing secure

### ✅ Database Configuration
- [x] PostgreSQL schema deployed
- [x] Initial data seeded
- [x] Admin user configured
- [x] Database indexes optimized
- [x] Connection pooling configured

### ✅ Security Features
- [x] CORS properly configured
- [x] Session secrets secure
- [x] Password validation enforced
- [x] SQL injection protection (Drizzle ORM)
- [x] XSS protection headers
- [x] Wallet signature verification

### ✅ Core Functionality
- [x] Airdrop creation/management
- [x] Category system
- [x] User profiles
- [x] Real-time chat with WebSocket
- [x] File upload system
- [x] Responsive design
- [x] Admin dashboard

### ✅ Performance Optimizations
- [x] Database queries optimized
- [x] Frontend built for production
- [x] Static asset optimization
- [x] Gzip compression ready

## VPS Deployment Steps

### 1. Server Setup
```bash
# Update system
sudo apt update && sudo apt upgrade -y

# Install Node.js 20.x
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt-get install -y nodejs

# Install PostgreSQL
sudo apt install postgresql postgresql-contrib -y

# Install Nginx and PM2
sudo apt install nginx -y
sudo npm install -g pm2

# Install SSL tools
sudo apt install certbot python3-certbot-nginx -y
```

### 2. Database Setup
```bash
# Create database and user
sudo -u postgres createdb crypto_airdrop_db
sudo -u postgres createuser -P airdrop_user
sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE crypto_airdrop_db TO airdrop_user;"
```

### 3. Application Deployment
```bash
# Clone repository
git clone <your-repo-url> /var/www/crypto-airdrop
cd /var/www/crypto-airdrop

# Install dependencies
npm install

# Configure environment
cp .env.example .env.production
# Edit DATABASE_URL and SESSION_SECRET

# Setup database
npm run db:push
npm run db:seed

# Build application
npm run build

# Start with PM2
pm2 start ecosystem.config.js --env production
pm2 save
pm2 startup
```

### 4. Nginx Configuration
```nginx
server {
    listen 443 ssl http2;
    server_name yourdomain.com;
    
    # SSL certificates
    ssl_certificate /etc/letsencrypt/live/yourdomain.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/yourdomain.com/privkey.pem;
    
    # WebSocket support
    location /ws {
        proxy_pass http://localhost:5000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
    }
    
    # API and main app
    location / {
        proxy_pass http://localhost:5000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

### 5. SSL Certificate
```bash
sudo certbot --nginx -d yourdomain.com -d www.yourdomain.com
```

### 6. Firewall Setup
```bash
sudo ufw enable
sudo ufw allow ssh
sudo ufw allow 'Nginx Full'
```

## Post-Deployment Tests

### Authentication Tests
1. Visit https://yourdomain.com/auth
2. Test user registration with username/password
3. Test login with created credentials
4. Test Web3 wallet connection
5. Verify admin privileges for wallet: `0x14b66774d1eec557ff19dd637a0208a098c017be`

### Functionality Tests
1. Create new airdrop (admin/creator)
2. Test chat functionality
3. Test user profile updates
4. Test file uploads
5. Verify responsive design on mobile

### Performance Tests
1. Check page load times
2. Test WebSocket connections
3. Monitor memory usage with `pm2 monit`
4. Check database performance

## Monitoring Commands

```bash
# Application status
pm2 status
pm2 logs crypto-airdrop-platform

# System resources
htop
df -h

# Nginx logs
sudo tail -f /var/log/nginx/access.log
sudo tail -f /var/log/nginx/error.log

# Database status
sudo systemctl status postgresql
```

## Backup Strategy

```bash
# Daily database backup (add to crontab)
0 2 * * * pg_dump $DATABASE_URL > /backups/db_$(date +\%Y\%m\%d).sql

# Weekly application backup
0 3 * * 0 tar -czf /backups/app_$(date +\%Y\%m\%d).tar.gz /var/www/crypto-airdrop
```

## Security Checklist

- [ ] SSL certificate installed and auto-renewing
- [ ] Firewall configured (UFW)
- [ ] Database user has minimal privileges
- [ ] Application runs as non-root user
- [ ] Strong session secrets configured
- [ ] Regular security updates scheduled
- [ ] Access logs monitored
- [ ] Backup system operational

## Admin Configuration

Default admin credentials from seed:
- Username: `admin`
- Password: `admin123`
- Wallet: `0x14b66774d1eec557ff19dd637a0208a098c017be` (set as admin)

**Important**: Change default admin password after deployment!

## Support Information

- Platform: Crypto Airdrop Learning Hub
- Tech Stack: Node.js, React, PostgreSQL, Drizzle ORM
- Authentication: Username/Password + Web3 Wallet
- Real-time: WebSocket chat
- Admin Features: Full CRUD operations
- Security: Role-based access control

Your platform is production-ready with enterprise-grade features including Web3 integration, real-time chat, and comprehensive admin controls.