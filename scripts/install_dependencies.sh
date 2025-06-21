#!/bin/bash
set -e
echo "Starting dependency installation..."
# Find where CodeDeploy extracted the files
echo "Current directory: $(pwd)"
echo "Looking for deployment directory..."

# CodeDeploy typically extracts to a deployment directory
# Let's find the most recent deployment directory by modification time
DEPLOYMENT_DIR=""

# Find the most recent deployment directory by modification time
LATEST_REQ_FILE=$(find /opt/codedeploy-agent/deployment-root -name "requirements.txt" -type f 2>/dev/null | head -1)

if [ -n "$LATEST_REQ_FILE" ]; then
    DEPLOYMENT_DIR=$(dirname "$LATEST_REQ_FILE")
    echo "Using most recent deployment: $LATEST_REQ_FILE"
elif [ -f "$CODEDEPLOY_ROOT/requirements.txt" ]; then
    DEPLOYMENT_DIR="$CODEDEPLOY_ROOT"
else
    # Last resort: search other locations
    for dir in /tmp/codedeploy-* /var/codedeploy-*; do
        if [ -f "$dir/requirements.txt" ]; then
            DEPLOYMENT_DIR="$dir"
            break
        fi
    done
fi

if [ -z "$DEPLOYMENT_DIR" ]; then
    echo "ERROR: Could not find deployment directory with requirements.txt"
    echo "Searching for any requirements.txt files:"
    find /opt /tmp /var -name "requirements.txt" 2>/dev/null || true
    exit 1
fi

echo "Found deployment directory: $DEPLOYMENT_DIR"
cd "$DEPLOYMENT_DIR"
echo "Files in deployment directory:"
ls -la

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

# Change to the user directory
cd /home/ec2-user

# Debug: Show what files we have
echo "Files copied to /home/ec2-user:"
ls -la

# Verify requirements.txt exists
echo "Checking if requirements.txt exists in /home/ec2-user..."
ls -la requirements.txt

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

# Check what main file we have (run.py or app.py)
MAIN_MODULE=""
if [ -f "run.py" ]; then
    MAIN_MODULE="run:app"
    echo "Found run.py - using run:app"
elif [ -f "app.py" ]; then
    MAIN_MODULE="app:app"
    echo "Found app.py - using app:app"
elif [ -f "main.py" ]; then
    MAIN_MODULE="main:app"
    echo "Found main.py - using main:app"
else
    echo "ERROR: Could not find main application file (run.py, app.py, or main.py)"
    exit 1
fi

# Create systemd service with proper paths and module
echo "Creating systemd service..."
sudo tee /etc/systemd/system/gamerhub.service > /dev/null <<EOF
[Unit]
Description=GamerHub Flask App
After=network.target

[Service]
Type=simple
User=ec2-user
Group=ec2-user
WorkingDirectory=/home/ec2-user
Environment="PATH=/home/ec2-user/venv/bin:/usr/local/bin:/usr/bin:/bin"
Environment="PYTHONPATH=/home/ec2-user"
ExecStart=/home/ec2-user/venv/bin/gunicorn -w 3 -b 0.0.0.0:8000 --chdir /home/ec2-user $MAIN_MODULE
Restart=always
RestartSec=5
StandardOutput=syslog
StandardError=syslog
SyslogIdentifier=gamerhub

[Install]
WantedBy=multi-user.target
EOF

# Reload systemd and enable the service
echo "Reloading systemd..."
sudo systemctl daemon-reload
sudo systemctl enable gamerhub

echo "Dependency installation completed successfully!"
echo "Main module set to: $MAIN_MODULE"
