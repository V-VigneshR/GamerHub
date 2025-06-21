#!/bin/bash
set -e
echo "Starting GamerHub service..."

# Debug information
echo "=== Debug Information ==="
echo "Current directory: $(pwd)"
echo "Files in /home/ec2-user:"
ls -la /home/ec2-user/ | head -10

echo "Python files:"
ls -la /home/ec2-user/*.py 2>/dev/null || echo "No .py files found"

echo "Virtual environment:"
if [ -d "/home/ec2-user/venv" ]; then
    echo "venv exists"
else
    echo "ERROR: venv does not exist!"
    exit 1
fi

# Test the application manually first
echo "=== Testing Application Manually ==="
cd /home/ec2-user
source venv/bin/activate

# Determine which main module to use
MAIN_MODULE=""
if [ -f "run.py" ]; then
    MAIN_MODULE="run:app"
    echo "Using run:app"
    echo "Testing run module import..."
    python -c "import run; print('✓ run module imported successfully')" || {
        echo "✗ Failed to import run module"
        python -c "import run" 2>&1 || true
        exit 1
    }
elif [ -f "app.py" ]; then
    MAIN_MODULE="app:app"  
    echo "Using app:app"
    echo "Testing app module import..."
    python -c "import app; print('✓ app module imported successfully')" || {
        echo "✗ Failed to import app module"
        python -c "import app" 2>&1 || true
        exit 1
    }
elif [ -f "main.py" ]; then
    MAIN_MODULE="main:app"
    echo "Using main:app"
    echo "Testing main module import..."
    python -c "import main; print('✓ main module imported successfully')" || {
        echo "✗ Failed to import main module"
        python -c "import main" 2>&1 || true
        exit 1
    }
else
    echo "ERROR: No main application file found (run.py, app.py, or main.py)"
    exit 1
fi

echo "✓ Application module test passed"

# Test gunicorn manually
echo "=== Testing Gunicorn ==="
echo "Gunicorn path: $(which gunicorn)"
timeout 5 gunicorn --check-config -w 1 -b 127.0.0.1:8001 $MAIN_MODULE || {
    echo "✗ Gunicorn config test failed"
    exit 1
}
echo "✓ Gunicorn config test passed"

# Now start the systemd service
echo "=== Starting SystemD Service ==="
sudo systemctl daemon-reload
sudo systemctl start gamerhub
sudo systemctl enable gamerhub

# Wait a bit for service to start
sleep 5

# Check if service is running
if systemctl is-active --quiet gamerhub; then
    echo "✓ GamerHub service started successfully!"
    sudo systemctl status gamerhub --no-pager -l
    
    # Test if the service is actually responding
    echo "=== Testing Service Response ==="
    if curl -f -s http://localhost:8000/ > /dev/null; then
        echo "✓ Service is responding to HTTP requests"
    else
        echo "⚠ Service is running but not responding to HTTP requests"
        echo "This might be normal if your app doesn't have a root route"
    fi
else
    echo "✗ Failed to start GamerHub service"
    echo "=== Service Status ==="
    sudo systemctl status gamerhub --no-pager -l
    echo "=== Recent Logs ==="
    sudo journalctl -u gamerhub --no-pager -l --since "2 minutes ago"
    exit 1
fi

echo "✓ Server startup completed successfully!"
