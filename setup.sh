#!/bin/bash
# Web GUI Setup Script - Run via SSH

# 1. Install Core Components
sudo apt update && sudo apt install -y \
    nginx \
    filebrowser \
    python3-pip \
    firefox-esr \
    geckodriver \
    xvfb

# 2. Install Python Requirements
sudo pip3 install flask flask-sse selenium python-dotenv

# 3. Create Project Structure
mkdir -p ~/webgui/{static/css,static/js,templates}
cat << 'EOF' > ~/webgui/app.py
from flask import Flask, render_template, request
from flask_sse import sse
import subprocess
import os

app = Flask(__name__)
app.config["REDIS_URL"] = "redis://localhost"
app.register_blueprint(sse, url_prefix='/stream')

@app.route('/')
def index():
    return render_template('dashboard.html')

@app.route('/download', methods=['POST'])
def download():
    url = request.form.get('url')
    # Add CivitAI API integration here
    subprocess.Popen(f"wget -P ~/downloads '{url}'", shell=True)
    return "Download started!"

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)
EOF

# 4. Create Web Interface Templates
cat << 'EOF' > ~/webgui/templates/dashboard.html
<!DOCTYPE html>
<html>
<head>
    <title>Pi Web GUI</title>
    <link href="https://unpkg.com/tailwindcss@^2/dist/tailwind.min.css" rel="stylesheet">
</head>
<body class="bg-gray-100">
    <div class="container mx-auto px-4 py-8">
        <div class="bg-white rounded-lg shadow-lg p-6">
            <h1 class="text-3xl font-bold mb-6">Raspberry Pi Web GUI</h1>
            
            <!-- File Browser Section -->
            <div class="mb-8">
                <h2 class="text-xl font-semibold mb-4">File Manager</h2>
                <iframe src="http://localhost:8080" 
                        class="w-full h-96 border rounded-lg"></iframe>
            </div>

            <!-- Download Manager -->
            <div class="mb-8">
                <h2 class="text-xl font-semibold mb-4">Download Files</h2>
                <div class="flex gap-4">
                    <input type="url" id="downloadUrl" 
                           class="flex-1 p-2 border rounded" 
                           placeholder="Enter download URL">
                    <button onclick="startDownload()" 
                            class="bg-blue-500 text-white px-6 py-2 rounded hover:bg-blue-600">
                        Download
                    </button>
                </div>
                <div id="progress" class="mt-4 space-y-2"></div>
            </div>
        </div>
    </div>

    <script>
    function startDownload() {
        const url = document.getElementById('downloadUrl').value;
        fetch('/download', {
            method: 'POST',
            headers: {'Content-Type': 'application/x-www-form-urlencoded'},
            body: `url=${encodeURIComponent(url)}`
        });
    }

    // Real-time updates
    const eventSource = new EventSource('/stream');
    eventSource.onmessage = (e) => {
        const progress = document.createElement('div');
        progress.className = 'p-3 bg-gray-50 rounded';
        progress.textContent = `Downloading: ${e.data}`;
        document.getElementById('progress').appendChild(progress);
    };
    </script>
</body>
</html>
EOF

# 5. Configure Services
sudo tee /etc/systemd/system/webgui.service > /dev/null <<EOF
[Unit]
Description=Web GUI Service
After=network.target

[Service]
User=$USER
WorkingDirectory=/home/$USER/webgui
ExecStart=/usr/bin/python3 app.py

[Install]
WantedBy=multi-user.target
EOF

# 6. Enable and Start
sudo systemctl daemon-reload
sudo systemctl enable --now webgui filebrowser nginx
sudo ufw allow 80,443,5000

# Completion
echo -e "\n\033[1;32m✔ Setup Complete!\033[0m"
echo -e "Access your web GUI at: \033[1;34mhttp://$(curl -s ifconfig.me)\033[0m"