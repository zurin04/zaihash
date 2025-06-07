# 🚀 One-Click VPS Deployment

Deploy your crypto airdrop platform to any VPS in under 10 minutes with a single command.

## Quick Start

### Option 1: Direct Download & Run
```bash
curl -fsSL https://raw.githubusercontent.com/yourusername/crypto-airdrop-platform/main/vps-auto-setup.sh | bash
```

### Option 2: Clone & Run
```bash
git clone https://github.com/yourusername/crypto-airdrop-platform.git
cd crypto-airdrop-platform
chmod +x vps-auto-setup.sh
./vps-auto-setup.sh
```

## What You Need

- **VPS Requirements:**
  - Ubuntu 20.04+ or Debian 11+
  - 1GB+ RAM
  - 20GB+ storage
  - Root/sudo access

- **Optional:**
  - Domain name pointed to your VPS IP
  - Email address for SSL certificate

## What The Script Does

The automated setup handles everything:

✅ **System Setup**
- Updates packages
- Installs Node.js 20, PostgreSQL, Nginx, PM2
- Configures firewall (UFW)

✅ **Database Configuration**
- Creates PostgreSQL database and user
- Generates secure passwords
- Sets up authentication

✅ **Application Deployment**
- Clones your repository
- Installs dependencies
- Builds the application
- Creates production environment

✅ **Process Management**
- Configures PM2 for auto-restart
- Sets up system startup scripts
- Creates monitoring dashboard

✅ **Web Server**
- Configures Nginx reverse proxy
- Sets up SSL certificates (if domain provided)
- Enables security headers

✅ **Maintenance Tools**
- Daily database backups
- Update scripts
- Log management

## During Setup

The script will ask for:

1. **Domain name** (optional - leave blank to use IP)
2. **Email address** (for SSL certificate if using domain)
3. **Database password** (optional - auto-generated if blank)
4. **Git repository URL** (your forked repository)

## After Installation

### Default Access
- **Application URL:** `http://your-domain.com` or `http://your-vps-ip`
- **Admin Login:** `admin` / `admin123`
- **Demo Login:** `demo` / `demo123`

### Important Security Steps
1. **Change default passwords immediately**
2. **Save database credentials** (displayed at end of setup)
3. **Update your repository URL** in the setup script

### Useful Commands
```bash
# View application status
pm2 status

# View application logs
pm2 logs crypto-airdrop-platform

# Restart application
pm2 restart crypto-airdrop-platform

# Update application
sudo /opt/crypto-airdrop/scripts/update.sh

# Manual backup
sudo /opt/crypto-airdrop/scripts/backup.sh

# View system status
sudo systemctl status nginx postgresql
```

## Troubleshooting

### Application Not Starting
```bash
# Check detailed logs
pm2 logs crypto-airdrop-platform --lines 50

# Check if port is available
sudo lsof -i :5000
```

### Database Connection Issues
```bash
# Test database connection
sudo -u postgres psql -d crypto_airdrop_db -U airdrop_user

# Check PostgreSQL status
sudo systemctl status postgresql
```

### Nginx Issues
```bash
# Test configuration
sudo nginx -t

# Check error logs
sudo tail -f /var/log/nginx/error.log
```

## Features Included

- **User Management:** Registration, authentication, roles
- **Airdrop Listings:** Create, view, manage crypto airdrops
- **Real-time Chat:** WebSocket-powered community chat
- **Crypto Tracker:** Live cryptocurrency price feeds
- **Admin Dashboard:** User management, content moderation
- **Creator System:** Application process for content creators
- **Newsletter:** Email subscription management
- **Mobile Responsive:** Works on all devices

## Security Features

- **SSL/TLS encryption** (if domain provided)
- **Firewall configuration** with UFW
- **Security headers** in Nginx
- **Database password encryption**
- **Session management** with secure secrets
- **Input validation** and sanitization

## Support

If you encounter issues:

1. Check the comprehensive logs provided during setup
2. Review the troubleshooting section above
3. Ensure your VPS meets the minimum requirements
4. Verify your domain DNS settings (if using a domain)

The script provides detailed error messages and recovery suggestions for common issues.

---

**Total setup time:** 5-10 minutes  
**Manual configuration required:** None  
**Production ready:** Yes