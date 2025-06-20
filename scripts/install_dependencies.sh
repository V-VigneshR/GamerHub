#!/bin/bash
cd /home/ec2-user
unzip -o flask-app.zip

# Install dependencies with Python 3.12
/usr/local/bin/python3.12 -m pip install -r requirements.txt

# Create the systemd service with correct configuration
sudo tee /etc/systemd/system/gamerhub.service > /dev/null <<EOF
[Unit]
Description=GamerHub Flask App
After=network.target

[Service]
Type=exec
User=ec2-user
Group=ec2-user
WorkingDirectory=/home/ec2-user
Environment=PATH=/usr/local/bin:/usr/bin:/bin
Environment=PYTHONPATH=/home/ec2-user
ExecStart=/usr/local/bin/gunicorn -w 3 -b 0.0.0.0:8000 run:app
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

# Reload systemd and enable the service
sudo systemctl daemon-reload
sudo systemctl enable gamerhub