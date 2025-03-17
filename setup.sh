#!/bin/bash

# Stop and remove existing services
sudo systemctl stop aria2.service webui.service
sudo systemctl disable aria2.service webui.service
sudo rm -f /etc/systemd/system/aria2.service /etc/systemd/system/webui.service
sudo rm -rf /home/leon/.aria2 /home/leon/webui /var/www/ariang

# Remove installed packages
sudo apt remove --purge -y nginx aria2 firefox xrdp samba nodejs npm
sudo apt autoremove -y

# Update system
sudo apt update && sudo apt upgrade -y

# Reinstall necessary packages
sudo apt install -y nginx aria2 firefox xrdp samba nodejs npm

# Install FileBrowser manually
curl -fsSL https://github.com/filebrowser/filebrowser/releases/latest/download/linux-arm64-filebrowser.tar.gz | sudo tar -xz -C /usr/local/bin filebrowser
sudo chmod +x /usr/local/bin/filebrowser

# Set up Aria2 configuration
mkdir -p /home/leon/.aria2
cat <<EOF > /home/leon/.aria2/aria2.conf
dir=/home/leon/Downloads
file-allocation=none
continue=true
max-concurrent-downloads=5
log=/var/log/aria2.log
input-file=/home/leon/.aria2/session
save-session=/home/leon/.aria2/session
rpc-allow-origin-all=true
rpc-listen-all=true
rpc-secret=changeme
EOF

# Enable Aria2 service
cat <<EOF | sudo tee /etc/systemd/system/aria2.service
[Unit]
Description=Aria2c Daemon
After=network.target

[Service]
ExecStart=/usr/bin/aria2c --enable-rpc --conf-path=/home/leon/.aria2/aria2.conf
Restart=always
User=leon

[Install]
WantedBy=multi-user.target
EOF
sudo systemctl enable aria2.service
sudo systemctl start aria2.service

# Install AriaNg
sudo mkdir -p /var/www/ariang
cd /var/www/ariang
sudo wget -qO- https://github.com/mayswind/AriaNg/releases/latest/download/AriaNg.zip | sudo busybox unzip -
sudo chown -R www-data:www-data /var/www/ariang

# Configure Nginx for AriaNg and File Browser
sudo tee /etc/nginx/sites-available/default <<EOF
server {
    listen 80;
    server_name _;

    location /ariang {
        root /var/www;
        index index.html;
    }

    location /files {
        proxy_pass http://127.0.0.1:8080/;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
    }

    location /webui {
        proxy_pass http://127.0.0.1:3000/;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
    }
}
EOF
sudo systemctl restart nginx

# Start File Browser on port 8080
sudo filebrowser -r /home/leon/Downloads -p 8080 --address 0.0.0.0 &

# Set up Samba for file sharing
cat <<EOF | sudo tee -a /etc/samba/smb.conf
[Downloads]
   path = /home/leon/Downloads
   read only = no
   browsable = yes
   guest ok = yes
EOF
sudo systemctl restart smbd

# Install web interface
mkdir -p /home/leon/webui
cd /home/leon/webui
npx create-next-app@latest . --use-npm --typescript
npm install axios lucide-react @shadcn/ui recharts

# Create systemd service for web UI
cat <<EOF | sudo tee /etc/systemd/system/webui.service
[Unit]
Description=Web UI Service
After=network.target

[Service]
WorkingDirectory=/home/leon/webui
ExecStart=/usr/bin/npm start -- -H 0.0.0.0
Restart=always
User=leon

[Install]
WantedBy=multi-user.target
EOF

# Enable and start Web UI service
sudo systemctl enable webui.service
sudo systemctl start webui.service

echo "Setup complete! Access your services:"
echo "  - AriaNg:       http://<RaspberryPi_IP>/ariang"
echo "  - File Browser: http://<RaspberryPi_IP>/files"
echo "  - Web UI:       http://<RaspberryPi_IP>/webui"
