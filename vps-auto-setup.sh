#!/bin/bash

# Crypto Airdrop Platform - VPS Auto Setup Script
# This script automates the complete deployment process

set -e  # Exit on any error

# Make script executable
chmod +x "$0"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to generate random password
generate_password() {
    openssl rand -base64 32 | tr -d "=+/" | cut -c1-25
}

# Function to generate session secret
generate_session_secret() {
    openssl rand -hex 64
}

# Check if running as root
if [[ $EUID -eq 0 ]]; then
   print_error "This script should not be run as root for security reasons"
   print_status "Please run as a regular user with sudo privileges"
   exit 1
fi

print_status "Starting Crypto Airdrop Platform VPS Setup..."
echo

# Get configuration from user
read -p "Enter your domain name (e.g., example.com) or press Enter to use IP: " DOMAIN_NAME
read -p "Enter your email for SSL certificate (required if using domain): " EMAIL
read -p "Enter PostgreSQL password (or press Enter to auto-generate): " DB_PASSWORD
read -p "Enter Git repository URL: " REPO_URL

# Generate passwords if not provided
if [ -z "$DB_PASSWORD" ]; then
    DB_PASSWORD=$(generate_password)
    print_status "Generated database password: $DB_PASSWORD"
fi

SESSION_SECRET=$(generate_session_secret)
APP_PORT=5000

print_status "Configuration:"
echo "Domain: ${DOMAIN_NAME:-'Using IP address'}"
echo "Email: ${EMAIL:-'Not provided'}"
echo "Repository: $REPO_URL"
echo "App Port: $APP_PORT"
echo

# Update system
print_status "Updating system packages..."
sudo apt update && sudo apt upgrade -y

# Install required packages
print_status "Installing required packages..."
sudo apt install -y postgresql postgresql-contrib nginx certbot python3-certbot-nginx curl git ufw

# Install Node.js 20
print_status "Installing Node.js 20..."
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt install -y nodejs

# Install PM2
print_status "Installing PM2..."
sudo npm install -g pm2

# Configure PostgreSQL
print_status "Configuring PostgreSQL..."
sudo systemctl start postgresql
sudo systemctl enable postgresql

# Create database and user
print_status "Creating database and user..."
sudo -u postgres psql <<EOF
CREATE DATABASE crypto_airdrop_db;
CREATE USER airdrop_user WITH PASSWORD '$DB_PASSWORD';
GRANT ALL PRIVILEGES ON DATABASE crypto_airdrop_db TO airdrop_user;
GRANT ALL ON SCHEMA public TO airdrop_user;
ALTER USER airdrop_user CREATEDB;
\q
EOF

# Configure PostgreSQL authentication
print_status "Configuring PostgreSQL authentication..."
PG_VERSION=$(sudo -u postgres psql -t -c "SELECT version();" | grep -oP '(?<=PostgreSQL )\d+')
PG_HBA_PATH="/etc/postgresql/$PG_VERSION/main/pg_hba.conf"

# Backup original pg_hba.conf
sudo cp "$PG_HBA_PATH" "$PG_HBA_PATH.backup"

# Add authentication line for our database
sudo sed -i "/^local.*all.*postgres.*peer/a local   crypto_airdrop_db    airdrop_user                     md5" "$PG_HBA_PATH"

# Restart PostgreSQL
sudo systemctl restart postgresql

# Create application directory
print_status "Setting up application directory..."
sudo mkdir -p /var/www/crypto-airdrop
sudo chown $USER:$USER /var/www/crypto-airdrop
cd /var/www/crypto-airdrop

# Clone repository
print_status "Cloning repository..."
git clone "$REPO_URL" .

# Install dependencies
print_status "Installing Node.js dependencies..."
npm install

# Create environment file
print_status "Creating environment configuration..."
cat > .env.production << EOF
NODE_ENV=production
DATABASE_URL=postgresql://airdrop_user:$DB_PASSWORD@localhost:5432/crypto_airdrop_db
SESSION_SECRET=$SESSION_SECRET
PORT=$APP_PORT
EOF

# Set proper permissions
chmod 600 .env.production

# Setup database
print_status "Setting up database schema..."
export NODE_ENV=production
npm run db:push

print_status "Seeding database with initial data..."
npm run db:seed

# Build application
print_status "Building application..."
npm run build

# Create PM2 ecosystem file
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

# Start application with PM2
print_status "Starting application..."
pm2 start ecosystem.config.js
pm2 save
pm2 startup | tail -1 | sudo bash

# Configure Nginx
print_status "Configuring Nginx..."
if [ -n "$DOMAIN_NAME" ]; then
    SERVER_NAME="$DOMAIN_NAME www.$DOMAIN_NAME"
else
    SERVER_NAME="_"
fi

sudo tee /etc/nginx/sites-available/crypto-airdrop > /dev/null << EOF
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

    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header Referrer-Policy "no-referrer-when-downgrade" always;
    add_header Content-Security-Policy "default-src 'self' http: https: data: blob: 'unsafe-inline'" always;
}
EOF

# Enable site
sudo ln -sf /etc/nginx/sites-available/crypto-airdrop /etc/nginx/sites-enabled/
sudo rm -f /etc/nginx/sites-enabled/default

# Test and restart Nginx
sudo nginx -t
sudo systemctl restart nginx
sudo systemctl enable nginx

# Configure firewall
print_status "Configuring firewall..."
sudo ufw --force enable
sudo ufw allow ssh
sudo ufw allow 'Nginx Full'
sudo ufw allow 22/tcp
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp

# Install SSL certificate if domain is provided
if [ -n "$DOMAIN_NAME" ] && [ -n "$EMAIL" ]; then
    print_status "Installing SSL certificate..."
    sudo certbot --nginx -d "$DOMAIN_NAME" -d "www.$DOMAIN_NAME" --non-interactive --agree-tos --email "$EMAIL"
fi

# Create backup script
print_status "Creating backup script..."
sudo mkdir -p /opt/crypto-airdrop/scripts
sudo tee /opt/crypto-airdrop/scripts/backup.sh > /dev/null << EOF
#!/bin/bash
BACKUP_DIR="/opt/crypto-airdrop/backups"
DATE=\$(date +%Y%m%d_%H%M%S)

mkdir -p \$BACKUP_DIR

# Database backup
PGPASSWORD='$DB_PASSWORD' pg_dump -U airdrop_user -h localhost crypto_airdrop_db > \$BACKUP_DIR/db_backup_\$DATE.sql

# Keep only last 7 days of backups
find \$BACKUP_DIR -name "db_backup_*.sql" -mtime +7 -delete

echo "Backup completed: \$DATE"
EOF

sudo chmod +x /opt/crypto-airdrop/scripts/backup.sh

# Setup daily backup cron job
print_status "Setting up daily backups..."
(crontab -l 2>/dev/null; echo "0 2 * * * /opt/crypto-airdrop/scripts/backup.sh") | crontab -

# Create update script
print_status "Creating update script..."
sudo tee /opt/crypto-airdrop/scripts/update.sh > /dev/null << EOF
#!/bin/bash
cd /var/www/crypto-airdrop
git pull
npm install
npm run build
pm2 restart crypto-airdrop-platform
echo "Application updated successfully"
EOF

sudo chmod +x /opt/crypto-airdrop/scripts/update.sh

# Final status check
print_status "Performing final checks..."
sleep 5

# Check if application is running
if pm2 list | grep -q "crypto-airdrop-platform.*online"; then
    print_success "Application is running successfully!"
else
    print_error "Application failed to start. Check logs with: pm2 logs crypto-airdrop-platform"
fi

# Check if Nginx is serving
if curl -s http://localhost:$APP_PORT > /dev/null; then
    print_success "Application is responding on port $APP_PORT"
else
    print_error "Application is not responding. Check application logs."
fi

# Display final information
echo
print_success "=== DEPLOYMENT COMPLETED ==="
echo
print_status "Application Details:"
echo "• Application URL: http://${DOMAIN_NAME:-$(curl -s ifconfig.me)}"
echo "• Database: crypto_airdrop_db"
echo "• Database User: airdrop_user"
echo "• Database Password: $DB_PASSWORD"
echo
print_status "Default Login Credentials:"
echo "• Admin User: admin / admin123"
echo "• Demo User: demo / demo123"
echo
print_warning "IMPORTANT SECURITY NOTES:"
echo "• Change default passwords immediately after login"
echo "• Database password saved in: /var/www/crypto-airdrop/.env.production"
echo "• Keep your environment file secure (chmod 600)"
echo
print_status "Useful Commands:"
echo "• View logs: pm2 logs crypto-airdrop-platform"
echo "• Restart app: pm2 restart crypto-airdrop-platform"
echo "• Update app: sudo /opt/crypto-airdrop/scripts/update.sh"
echo "• Manual backup: sudo /opt/crypto-airdrop/scripts/backup.sh"
echo "• View status: pm2 status"
echo
if [ -n "$DOMAIN_NAME" ] && [ -n "$EMAIL" ]; then
    print_success "SSL certificate installed! Your site is accessible at: https://$DOMAIN_NAME"
else
    print_status "To add SSL later, run: sudo certbot --nginx"
fi

print_success "Setup completed successfully! Your crypto airdrop platform is now live!"