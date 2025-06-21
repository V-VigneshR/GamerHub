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

# Show current requirements.txt
echo "Current requirements.txt content:"
cat requirements.txt

# Create a backup of original requirements
cp requirements.txt requirements.txt.backup

# Fix SQLAlchemy compatibility issues by pinning versions
echo "Fixing SQLAlchemy compatibility..."
cat > requirements_fixed.txt << 'EOF'
Flask==2.3.3
Flask-SQLAlchemy==3.0.5
SQLAlchemy==2.0.23
Flask-Migrate==4.0.5
Werkzeug==2.3.7
gunicorn==21.2.0
Jinja2==3.1.2
MarkupSafe==2.1.3
click==8.1.7
itsdangerous==2.1.2
alembic==1.12.1
Mako==1.2.4
python-dateutil==2.8.2
six==1.16.0
typing_extensions==4.8.0
greenlet==3.0.1
EOF

# If original requirements has additional packages not in our fixed list, append them
echo "Checking for additional packages in original requirements..."
while IFS= read -r line; do
    # Skip comments and empty lines
    [[ "$line" =~ ^[[:space:]]*# ]] && continue
    [[ -z "${line// }" ]] && continue
    
    # Extract package name (before == or >= etc.)
    pkg_name=$(echo "$line" | sed 's/[>=<].*//' | tr '[:upper:]' '[:lower:]')
    
    # Check if package is already in our fixed requirements
    if ! grep -qi "^${pkg_name}==" requirements_fixed.txt; then
        echo "Adding additional package: $line"
        echo "$line" >> requirements_fixed.txt
    fi
done < requirements.txt

# Use the fixed requirements
mv requirements_fixed.txt requirements.txt

echo "Updated requirements.txt:"
cat requirements.txt

# Create virtual environment
echo "Setting up virtualenv with default Python..."
rm -rf venv
python3 -m venv venv
source venv/bin/activate

# Install dependencies with fixed versions
echo "Installing Python dependencies with fixed versions..."
pip install --upgrade pip

# Install packages individually to catch any issues
pip install Flask==2.3.3
pip install SQLAlchemy==2.0.23
pip install Flask-SQLAlchemy==3.0.5
pip install Werkzeug==2.3.7
pip install gunicorn==21.2.0

# Install remaining requirements
pip install -r requirements.txt

# Test the imports
echo "Testing critical imports..."
python -c "import flask; print(f'✓ Flask {flask.__version__}')"
python -c "import sqlalchemy; print(f'✓ SQLAlchemy {sqlalchemy.__version__}')"
python -c "from flask_sqlalchemy import SQLAlchemy; print('✓ Flask-SQLAlchemy imported')"
python -c "import gunicorn; print('✓ Gunicorn imported')"

# Test your app import
echo "Testing app import..."
python -c "from app import create_app; print('✓ create_app imported successfully')"
python -c "from app import create_app, db; app = create_app(); print('✓ App created successfully')"

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
Type=simple
User=ec2-user
Group=ec2-user
WorkingDirectory=/home/ec2-user
Environment="PATH=/home/ec2-user/venv/bin:/usr/local/bin:/usr/bin:/bin"
Environment="PYTHONPATH=/home/ec2-user"
ExecStart=/home/ec2-user/venv/bin/gunicorn -w 3 -b 0.0.0.0:8000 --chdir /home/ec2-user run:app
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
echo "SQLAlchemy compatibility issues have been fixed."
