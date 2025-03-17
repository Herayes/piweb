#!/bin/bash
# Corrected Raspberry Pi Web Server Setup Script

# Fix missing dependencies and Python environment
sudo apt update && sudo apt install -y \
    software-properties-common \
    ufw \
    python3.11-venv

# Install FileBrowser properly
curl -fsSL https://raw.githubusercontent.com/filebrowser/get/master/get.sh | bash
sudo mv filebrowser /usr/local/bin/

# Install geckodriver manually
GECKO_VER=$(curl -s https://api.github.com/repos/mozilla/geckodriver/releases/latest | grep tag_name | cut -d'"' -f4)
wget https://github.com/mozilla/geckodriver/releases/download/${GECKO_VER}/geckodriver-${GECKO_VER}-linux-armv7l.tar.gz
tar -xzf geckodriver-*.tar.gz
chmod +x geckodriver
sudo mv geckodriver /usr/local/bin/

# Create Python virtual environment
python3 -m venv ~/webgui-venv
source ~/webgui-venv/bin/activate

# Install Python packages safely
pip install --upgrade pip
pip install flask flask-sse selenium python-dotenv

# Fix service file creation
sudo tee /etc/systemd/system/filebrowser.service > /dev/null <<EOF
[Unit]
Description=FileBrowser
After=network.target

[Service]
User=$(whoami)
ExecStart=/usr/local/bin/filebrowser -d /home/$(whoami)/filebrowser.db

[Install]
WantedBy=multi-user.target
EOF

# Configure firewall properly
sudo ufw allow 80,8080,5000/tcp
sudo ufw --force enable

# Enable services correctly
sudo systemctl daemon-reload
sudo systemctl enable filebrowser
sudo systemctl start filebrowser

echo -e "\n\033[1;32m✔ Setup Completed Successfully!\033[0m"
echo -e "Access your dashboard at: http://$(hostname -I | awk '{print $1}'):5000"
