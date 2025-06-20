#!/bin/bash
set -e

echo "Starting dependency installation..."
cd /home/ec2-user

# Unzip the new application
echo "Extracting flask-app.zip..."
unzip -o flask-app.zip

# Set correct ownership
chown -R ec2-user:ec2-user /home/ec2-user/

# Create virtual environment
echo "Setting up virtualenv with default Python..."
python3 -m venv venv
source venv/bin/activate

# Install dependencies
echo "Installing Python dependencies..."
pip install --upgrade pip
pip install -r requirements.txt

# Verify installations
echo "Verifying Flask and Gunicorn installation..."
python -c "from flask import Flask; print('Flask is available')"
gunicorn --version

# Create systemd service
echo "Creating systemd service..."
sudo tee /etc/systemd/system/gamerhub.service > /dev/null <<EOF
[Unit]
Description=GamerHub Flask App
After=network.target

[Service]
User=ec2-user
Group=ec2-user
WorkingDirectory=/home/ec2-user
Environment="PATH=/home/ec2-user/venv/bin"
ExecStart=/home/ec2-user/venv/bin/gunicorn -w 3 -b 0.0.0.0:8000 run:app
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

# Reload systemd and enable the service
echo "Reloading systemd..."
sudo systemctl daemon-reload
sudo systemctl enable gamerhub

echo "Dependency installation completed successfully!"
