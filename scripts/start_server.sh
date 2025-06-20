#!/bin/bash

APP_DIR="/home/ec2-user"
ZIP_FILE="$APP_DIR/flask-app.zip"
SERVICE_FILE="/etc/systemd/system/gamerhub.service"

# Unpack the app
cd $APP_DIR
unzip -o $ZIP_FILE

# Install Python packages
pip3 install -r $APP_DIR/requirements.txt

# Create/Overwrite the service file
cat << EOF | sudo tee $SERVICE_FILE
[Unit]
Description=GamerHub Flask App
After=network.target

[Service]
User=ec2-user
WorkingDirectory=$APP_DIR
ExecStart=/usr/local/bin/gunicorn -w 3 -b 0.0.0.0:8000 run:app
Restart=always

[Install]
WantedBy=multi-user.target
EOF

# Start service
sudo systemctl daemon-reexec
sudo systemctl daemon-reload
sudo systemctl enable gamerhub
sudo systemctl restart gamerhub
