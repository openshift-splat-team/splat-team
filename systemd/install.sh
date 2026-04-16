#!/bin/bash
# Install botminter systemd service

set -e

echo "Installing botminter systemd service..."

# Check if environment file exists and has been configured
if [ ! -f "botminter.env" ]; then
    echo "ERROR: botminter.env not found!"
    echo "Please create botminter.env with your credentials first."
    exit 1
fi

if grep -q "your-api-token-here" botminter.env; then
    echo "WARNING: botminter.env contains placeholder credentials."
    echo "Please edit botminter.env and add your real Jira API token."
    read -p "Continue anyway? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Copy startup script to system location
sudo cp botminter-start.sh /usr/local/bin/botminter-start
sudo chmod +x /usr/local/bin/botminter-start
sudo chown root:root /usr/local/bin/botminter-start

# Copy service file
sudo cp botminter.service /etc/systemd/system/

# Secure the environment file
chmod 600 botminter.env

# Reload systemd
sudo systemctl daemon-reload

echo "✓ Service installed"
echo ""
echo "IMPORTANT: Edit botminter.env with your credentials:"
echo "  vim $(pwd)/botminter.env"
echo ""
echo "Then enable and start:"
echo "  sudo systemctl enable botminter"
echo "  sudo systemctl start botminter"
echo ""
echo "To check status:"
echo "  sudo systemctl status botminter"
