#!/bin/bash
# Raspberry Pi Web Server Full Setup Script
# Run via: curl -sL https://raw.githubusercontent.com/Herayes/piweb/main/setup.sh | bash

# Error handling and cleanup
set -e
trap 'echo -e "\n\033[1;31m» ERROR at line $LINENO! «\033[0m"; exit 1' ERR
sudo rm -rf /tmp/pi-setup
mkdir -p /tmp/pi-setup

# System Configuration
USER=$(whoami)
IP=$(hostname -I | awk '{print $1}')
FB_DB="/home/$USER/filebrowser.db"
VENV_DIR="/home/$USER/webgui-venv"

# Install Core Dependencies
echo -e "\n\033[1;34m» Installing system dependencies...\033[0m"
sudo apt update && sudo apt install -y \
    nginx \
    firefox-esr \
    python3.11-venv \
    wget \
    tar \
    ufw

# Install FileBrowser
echo -e "\n\033[1;34m» Installing FileBrowser...\033[0m"
curl -fsSL https://raw.githubusercontent.com/filebrowser/get/master/get.sh | bash
sudo mv filebrowser /usr/local/bin/

# Install geckodriver
echo -e "\n\033[1;34m» Installing geckodriver...\033[0m"
GECKO_VER=$(curl -s https://api.github.com/repos/mozilla/geckodriver/releases/latest | grep tag_name | cut -d'"' -f4)
wget -q https://github.com/mozilla/geckodriver/releases/download/${GECKO_VER}/geckodriver-${GECKO_VER}-linux-armv7l.tar.gz -P /tmp/pi-setup
tar -xzf /tmp/pi-setup/geckodriver-*.tar.gz -C /tmp/pi-setup
chmod +x /tmp/pi-setup/geckodriver
sudo mv /tmp/pi-setup/geckodriver /usr/local/bin/

# Python Environment Setup
echo -e "\n\033[1;34m» Configuring Python environment...\033[0m"
python3 -m venv $VENV_DIR
source $VENV_DIR/bin/activate
pip install --upgrade pip
pip install flask flask-sse selenium python-dotenv

# FileBrowser Service Setup
echo -e "\n\033[1;34m» Configuring services...\033[0m"
sudo tee /etc/systemd/system/filebrowser.service > /dev/null <<EOF
[Unit]
Description=FileBrowser
After=network.target

[Service]
User=$USER
ExecStart=/usr/local/bin/filebrowser -d $FB_DB --root /home/$USER/files

[Install]
WantedBy=multi-user.target
EOF

# Nginx Configuration
sudo tee /etc/nginx/sites-available/webgui > /dev/null <<EOF
server {
    listen 80;
    server_name _;

    location / {
        proxy_pass http://localhost:5000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
    }

    location /files {
        proxy_pass http://localhost:8080;
        proxy_set_header Host \$host;
    }
}
EOF

# Enable Services
sudo ln -sf /etc/nginx/sites-available/webgui /etc/nginx/sites-enabled/
sudo systemctl daemon-reload
sudo systemctl enable --now filebrowser nginx

# Firewall Configuration
echo -e "\n\033[1;34m» Configuring firewall...\033[0m"
sudo ufw allow 80,8080,5000/tcp
sudo ufw allow ssh
sudo ufw --force enable

# Create File Structure
mkdir -p /home/$USER/webgui/{static,templates}
mkdir -p /home/$USER/files

# Final Output
echo -e "\n\033[1;32m✔ Setup Complete!\033[0m"
echo -e "\n\033[1;33mAccess Information:\033[0m"
echo -e "  Web Interface: \033[1;35mhttp://$IP\033[0m"
echo -e "  File Manager:  \033[1;35mhttp://$IP/files\033[0m"
echo -e "\n\033[1;33mManagement Commands:\033[0m"
echo -e "  Restart Services: sudo systemctl restart filebrowser nginx"
echo -e "  View Logs:        journalctl -u filebrowser -f"

# Cleanup
sudo rm -rf /tmp/pi-setup
