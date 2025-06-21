#!/bin/bash
set -e

echo "Starting dependency installation..."

# The files are already extracted by CodeDeploy, so we just need to copy them
echo "Copying application files to /home/ec2-user..."

# Remove any existing app files first
rm -rf /home/ec2-user/app /home/ec2-user/scripts /home/ec2-user/static /home/ec2-user/templates
rm -f /home/ec2-user/*.py /home/ec2-user/*.txt /home/ec2-user/*.yml /home/ec2-user/Procfile

# Copy only the application files (not system directories)
cp -r app /home/ec2-user/ 2>/dev/null || true
cp -r scripts /home/ec2-user/ 2>/dev/null || true
cp -r static /home/ec2-user/ 2>/dev/null || true
cp -r templates /home/ec2-user/ 2>/dev/null || true
cp -r tests /home/ec2-user/ 2>/dev/null || true
cp *.py /home/ec2-user/ 2>/dev/null || true
cp *.txt /home/ec2-user/ 2>/dev/null || true
cp *.yml /home/ec2-user/ 2>/dev/null || true
cp Procfile /home/ec2-user/ 2>/dev/null || true

# Set correct ownership
chown -R ec2-user:ec2-user /home/ec2-user/

cd /home/ec2-user

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
