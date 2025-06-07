#!/bin/bash

# Crypto Airdrop Platform - Root VPS Deployment Script
# Designed for fresh VPS instances running as root

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_status() { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }

generate_password() { openssl rand -base64 32 | tr -d "=+/" | cut -c1-25; }
generate_session_secret() { openssl rand -hex 64; }

print_status "🚀 Crypto Airdrop Platform - VPS Root Deployment"
echo "=================================================="
echo

# Get configuration
read -p "Enter your domain name (or press Enter to use IP): " DOMAIN_NAME
read -p "Enter your email for SSL (required if using domain): " EMAIL
read -p "Enter Git repository URL: " REPO_URL
read -p "Enter database password (or press Enter to auto-generate): " DB_PASSWORD

if [ -z "$DB_PASSWORD" ]; then
    DB_PASSWORD=$(generate_password)
    print_status "Generated database password: $DB_PASSWORD"
fi

SESSION_SECRET=$(generate_session_secret)
APP_PORT=5000

print_status "Configuration complete. Starting installation..."
echo

# Update system
print_status "Updating system packages..."
apt update && apt upgrade -y

# Install packages
print_status "Installing required packages..."
apt install -y postgresql postgresql-contrib nginx certbot python3-certbot-nginx curl git ufw

# Install Node.js 20
print_status "Installing Node.js 20..."
curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
apt install -y nodejs

# Install PM2
print_status "Installing PM2..."
npm install -g pm2

# Create application user
print_status "Creating application user..."
if ! id -u appuser >/dev/null 2>&1; then
    useradd -m -s /bin/bash appuser
    usermod -aG sudo appuser
    print_status "Created user 'appuser'"
fi

# Configure PostgreSQL
print_status "Configuring PostgreSQL..."
systemctl start postgresql
systemctl enable postgresql

# Create database
print_status "Setting up database..."
sudo -u postgres psql <<EOF
CREATE DATABASE crypto_airdrop_db;
CREATE USER airdrop_user WITH PASSWORD '$DB_PASSWORD';
GRANT ALL PRIVILEGES ON DATABASE crypto_airdrop_db TO airdrop_user;
GRANT ALL ON SCHEMA public TO airdrop_user;
ALTER USER airdrop_user CREATEDB;
\q
EOF

# Configure PostgreSQL authentication
PG_VERSION=$(sudo -u postgres psql -t -c "SELECT version();" | grep -oP '(?<=PostgreSQL )\d+')
PG_HBA_PATH="/etc/postgresql/$PG_VERSION/main/pg_hba.conf"
cp "$PG_HBA_PATH" "$PG_HBA_PATH.backup"
sed -i "/^local.*all.*postgres.*peer/a local   crypto_airdrop_db    airdrop_user                     md5" "$PG_HBA_PATH"
systemctl restart postgresql

# Setup application directory
print_status "Setting up application..."
mkdir -p /var/www/crypto-airdrop
cd /var/www/crypto-airdrop

# Clone repository
print_status "Cloning repository..."
git clone "$REPO_URL" .

# Install dependencies
print_status "Installing dependencies..."
npm install

# Create environment file
print_status "Creating environment configuration..."
cat > .env.production << EOF
NODE_ENV=production
DATABASE_URL=postgresql://airdrop_user:$DB_PASSWORD@localhost:5432/crypto_airdrop_db
SESSION_SECRET=$SESSION_SECRET
PORT=$APP_PORT
EOF

chmod 600 .env.production

# Setup database schema
print_status "Setting up database schema..."
export NODE_ENV=production
npm run db:push

print_status "Seeding database..."
npm run db:seed

# Build application
print_status "Building application..."
npm run build

# Create PM2 config
print_status "Creating PM2 configuration..."
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
      NODE_ENV: 'production'
    }
  }]
}
EOF

# Set ownership to appuser
chown -R appuser:appuser /var/www/crypto-airdrop

# Start application as appuser
print_status "Starting application..."
sudo -u appuser bash -c "cd /var/www/crypto-airdrop && pm2 start ecosystem.config.js"
sudo -u appuser pm2 save
sudo -u appuser pm2 startup | tail -1 | bash

# Configure Nginx
print_status "Configuring Nginx..."
if [ -n "$DOMAIN_NAME" ]; then
    SERVER_NAME="$DOMAIN_NAME www.$DOMAIN_NAME"
else
    SERVER_NAME="_"
fi

cat > /etc/nginx/sites-available/crypto-airdrop << EOF
server {
    listen 80;
    server_name $SERVER_NAME;

    location / {
        proxy_pass http://localhost:$APP_PORT;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_cache_bypass \$http_upgrade;
    }

    location /ws {
        proxy_pass http://localhost:$APP_PORT;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }

    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header Referrer-Policy "no-referrer-when-downgrade" always;
    add_header Content-Security-Policy "default-src 'self' http: https: data: blob: 'unsafe-inline'" always;
}
EOF

# Enable site
ln -sf /etc/nginx/sites-available/crypto-airdrop /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default
nginx -t
systemctl restart nginx
systemctl enable nginx

# Configure firewall
print_status "Configuring firewall..."
ufw --force enable
ufw allow ssh
ufw allow 'Nginx Full'
ufw allow 22/tcp
ufw allow 80/tcp
ufw allow 443/tcp

# SSL certificate
if [ -n "$DOMAIN_NAME" ] && [ -n "$EMAIL" ]; then
    print_status "Installing SSL certificate..."
    certbot --nginx -d "$DOMAIN_NAME" -d "www.$DOMAIN_NAME" --non-interactive --agree-tos --email "$EMAIL"
fi

# Create maintenance scripts
print_status "Creating maintenance scripts..."
mkdir -p /opt/crypto-airdrop/scripts

cat > /opt/crypto-airdrop/scripts/backup.sh << EOF
#!/bin/bash
BACKUP_DIR="/opt/crypto-airdrop/backups"
DATE=\$(date +%Y%m%d_%H%M%S)
mkdir -p \$BACKUP_DIR
PGPASSWORD='$DB_PASSWORD' pg_dump -U airdrop_user -h localhost crypto_airdrop_db > \$BACKUP_DIR/db_backup_\$DATE.sql
find \$BACKUP_DIR -name "db_backup_*.sql" -mtime +7 -delete
echo "Backup completed: \$DATE"
EOF

cat > /opt/crypto-airdrop/scripts/update.sh << EOF
#!/bin/bash
cd /var/www/crypto-airdrop
git pull
npm install
npm run build
sudo -u appuser pm2 restart crypto-airdrop-platform
echo "Application updated successfully"
EOF

chmod +x /opt/crypto-airdrop/scripts/*.sh

# Setup daily backup
(crontab -l 2>/dev/null; echo "0 2 * * * /opt/crypto-airdrop/scripts/backup.sh") | crontab -

# Final checks
print_status "Performing final checks..."
sleep 5

if sudo -u appuser pm2 list | grep -q "crypto-airdrop-platform.*online"; then
    print_success "Application is running!"
else
    print_error "Application failed to start. Check: sudo -u appuser pm2 logs crypto-airdrop-platform"
fi

if curl -s http://localhost:$APP_PORT > /dev/null; then
    print_success "Application responding on port $APP_PORT"
else
    print_warning "Application may still be starting..."
fi

# Display results
echo
print_success "=== DEPLOYMENT COMPLETED ==="
echo
print_status "Application Details:"
if [ -n "$DOMAIN_NAME" ]; then
    if [ -n "$EMAIL" ]; then
        echo "• URL: https://$DOMAIN_NAME"
    else
        echo "• URL: http://$DOMAIN_NAME"
    fi
else
    echo "• URL: http://$(curl -s ifconfig.me 2>/dev/null || echo 'YOUR_SERVER_IP')"
fi
echo "• Database: crypto_airdrop_db"
echo "• DB User: airdrop_user"
echo "• DB Password: $DB_PASSWORD"
echo
print_status "Default Login:"
echo "• Admin: admin / admin123"
echo "• Demo: demo / demo123"
echo
print_warning "SECURITY REMINDERS:"
echo "• Change default passwords after login"
echo "• Database credentials saved in /var/www/crypto-airdrop/.env.production"
echo
print_status "Management Commands:"
echo "• View status: sudo -u appuser pm2 status"
echo "• View logs: sudo -u appuser pm2 logs crypto-airdrop-platform"
echo "• Restart app: sudo -u appuser pm2 restart crypto-airdrop-platform"
echo "• Update app: /opt/crypto-airdrop/scripts/update.sh"
echo "• Backup DB: /opt/crypto-airdrop/scripts/backup.sh"
echo

print_success "Your crypto airdrop platform is now live!"