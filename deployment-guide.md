# Deployment Guide for Crypto Airdrop Task Hub

This guide outlines the steps needed to deploy the Crypto Airdrop Task Hub application to a production environment.

## System Requirements

- Node.js v18.x or later
- PostgreSQL 14.x or later
- At least 1GB RAM
- 10GB disk space minimum

## Environment Variables

Create a `.env` file with the following variables:

```
# Database Configuration
DATABASE_URL=postgresql://username:password@hostname/database
PGUSER=username
PGPASSWORD=password
PGDATABASE=database
PGHOST=hostname
PGPORT=5432

# Session Secret (generate a random string)
SESSION_SECRET=your_random_secret_string

# Optional: Web3 Configuration
ADMIN_WALLET_ADDRESS=0x28a08e5eb73f66621d6516969d65e2290ef460a1
```

## Installation Steps

1. **Clone Repository**

```bash
git clone <repository-url>
cd crypto-airdrop-task-hub
```

2. **Install Dependencies**

```bash
npm install
```

3. **Database Setup**

```bash
npm run db:push   # Create database schema
npm run db:seed   # Seed initial data
```

4. **Build for Production**

```bash
npm run build
```

5. **Start the Server**

```bash
npm start
```

## Server Configuration

### Nginx Configuration (Example)

```nginx
server {
    listen 80;
    server_name yourdomain.com;

    location / {
        proxy_pass http://localhost:5000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_cache_bypass $http_upgrade;
    }
    
    # WebSocket Support for Chat
    location /ws {
        proxy_pass http://localhost:5000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_cache_bypass $http_upgrade;
    }
}
```

### Process Management (PM2)

Install PM2:
```bash
npm install -g pm2
```

Create a PM2 configuration file (`ecosystem.config.js`):
```javascript
module.exports = {
  apps: [{
    name: 'crypto-airdrop-hub',
    script: 'server/index.js',
    instances: 1,
    autorestart: true,
    watch: false,
    max_memory_restart: '1G',
    env: {
      NODE_ENV: 'production'
    }
  }]
};
```

Start application with PM2:
```bash
pm2 start ecosystem.config.js
```

## Maintenance

- **Database Backups**
  ```bash
  pg_dump -U username -d database > backup.sql
  ```

- **Log Management**
  PM2 logs:
  ```bash
  pm2 logs crypto-airdrop-hub
  ```

## File Upload Directory

Ensure the `public/uploads/images` directory exists and has proper write permissions:

```bash
mkdir -p public/uploads/images
chmod -R 777 public/uploads
```

## Security Considerations

1. Regularly update dependencies:
   ```bash
   npm audit
   npm update
   ```

2. Set up SSL/TLS certificates for HTTPS using Let's Encrypt or similar service

3. Implement rate limiting for API endpoints to prevent abuse

4. Regularly backup the database

## Troubleshooting

- If WebSocket connections fail, ensure your proxy is properly configured to handle WebSocket upgrading
- For file upload issues, check permissions on the uploads directory
- Database connection problems: verify connection string and network access