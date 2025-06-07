#!/bin/bash

# Quick installer for Crypto Airdrop Platform
# Download and run the full setup script

set -e

echo "🚀 Crypto Airdrop Platform - One-Click VPS Setup"
echo "================================================"
echo

# Check if curl is available
if ! command -v curl &> /dev/null; then
    echo "Installing curl..."
    sudo apt update && sudo apt install -y curl
fi

# Download and run the setup script
echo "Downloading setup script..."
curl -fsSL https://raw.githubusercontent.com/yourusername/crypto-airdrop-platform/main/vps-auto-setup.sh -o vps-auto-setup.sh

chmod +x vps-auto-setup.sh

echo "Starting automated setup..."
./vps-auto-setup.sh

echo "Setup complete! Check the output above for your application URL and login credentials."