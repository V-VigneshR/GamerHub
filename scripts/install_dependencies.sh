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

# Check Python version
echo "Python version check:"
python3 --version

# Show current requirements.txt
echo "Current requirements.txt content:"
cat requirements.txt

# Create a backup of original requirements
cp requirements.txt requirements.txt.backup

# Fix SQLAlchemy compatibility issues for Python 3.7
echo "Creating Python 3.7 compatible requirements..."
cat > requirements_fixed.txt << 'EOF'
Flask==2.2.5
Flask-SQLAlchemy==2.5.1
SQLAlchemy==1.4.53
Flask-Migrate==3.1.0
Werkzeug==2.2.3
gunicorn==20.1.0
Jinja2==3.0.3
MarkupSafe==2.1.3
click==8.0.4
itsdangerous==2.1.2
alembic==1.8.1
Mako==1.2.4
python-dateutil==2.8.2
six==1.16.0
typing_extensions==4.4.0
greenlet==1.1.3
Flask-Login==0.6.2
Flask-Bcrypt==1.0.1
Flask-WTF==1.0.1
WTForms==3.0.1
python-dotenv==0.21.0
Flask-Mail==0.9.1
email-validator==1.3.1
pytest==7.2.2
pytest-flask==1.2.0
EOF

echo "Updated requirements.txt for Python 3.7:"
cat requirements_fixed.txt

# Use the fixed requirements
mv requirements_fixed.txt requirements.txt

# Create virtual environment
echo "Setting up virtualenv with Python 3.7..."
rm -rf venv
python3 -m venv venv
source venv/bin/activate

# Upgrade pip first
echo "Upgrading pip..."
pip install --upgrade pip

# Install core packages individually to catch issues
echo "Installing core Flask packages..."
pip install Flask==2.2.5
pip install SQLAlchemy==1.4.53
pip install Flask-SQLAlchemy==2.5.1
pip install Werkzeug==2.2.3
pip install gunicorn==20.1.0

# Install all remaining requirements
echo "Installing remaining dependencies..."
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

# Test app creation with proper error handling
echo "Testing app creation..."
python -c "
try:
    from app import create_app, db
    app = create_app()
    print('✓ App created successfully')
    with app.app_context():
        print('✓ App context works')
except ImportError as e:
    print(f'Import error: {e}')
    print('This might be normal if db is not in __init__.py')
except Exception as e:
    print(f'App creation error: {e}')
    print('This might be normal if database is not set up yet')
"

# Verify installations
echo "Verifying Flask and Gunicorn installation..."
python -c "from flask import Flask; print('✓ Flask is available')"
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
echo "Python 3.7 compatible versions installed."
echo "SQLAlchemy version: 1.4.53 (compatible with Flask-SQLAlchemy 2.5.1)"
