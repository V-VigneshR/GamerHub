#!/bin/bash
set -e  # Exit on any error

echo "Starting dependency installation..."
cd /home/ec2-user


# Unzip the new application
echo "Extracting flask-app.zip..."
unzip -o flask-app.zip

# Set correct ownership
chown -R ec2-user:ec2-user /home/ec2-user/

# Ensure Python 3.12 is available and install dependencies
echo "Installing Python dependencies..."
/usr/local/bin/python3.12 -m pip install --upgrade pip
/usr/local/bin/python3.12 -m pip install -r requirements.txt

echo "Verifying Flask installation..."
/usr/local/bin/python3.12 -c "from flask import Flask; print('Flask is available')"

echo "Verifying Gunicorn installation..."
/usr/local/bin/gunicorn --version

# Create the systemd service with correct configuration
echo "Creating systemd service..."
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
echo "Reloading systemd..."
sudo systemctl daemon-reload
sudo systemctl enable gamerhub

echo "Dependency installation completed successfully!"