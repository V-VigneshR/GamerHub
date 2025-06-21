#!/bin/bash
set -e
echo "Starting GamerHub service debugging..."

echo "=== SYSTEM INFORMATION ==="
echo "Current user: $(whoami)"
echo "Current directory: $(pwd)"
echo "Python version: $(python3 --version)"

echo "=== FILES IN /home/ec2-user ==="
ls -la /home/ec2-user/

echo "=== PYTHON FILES ==="
find /home/ec2-user -name "*.py" -type f | head -10

echo "=== CHECKING MAIN APPLICATION FILES ==="
cd /home/ec2-user

if [ -f "run.py" ]; then
    echo "✓ run.py exists"
    echo "Content of run.py (first 20 lines):"
    head -20 run.py
    echo "---"
else
    echo "✗ run.py does not exist"
fi

if [ -f "app.py" ]; then
    echo "✓ app.py exists"
    echo "Content of app.py (first 20 lines):"
    head -20 app.py
    echo "---"
else
    echo "✗ app.py does not exist"
fi

if [ -f "main.py" ]; then
    echo "✓ main.py exists"
    echo "Content of main.py (first 20 lines):"
    head -20 main.py
    echo "---"
else
    echo "✗ main.py does not exist"
fi

echo "=== APP DIRECTORY ==="
if [ -d "app" ]; then
    echo "✓ app directory exists"
    ls -la app/
    if [ -f "app/__init__.py" ]; then
        echo "app/__init__.py content:"
        head -10 app/__init__.py
    fi
    if [ -f "app/app.py" ]; then
        echo "app/app.py content:"
        head -10 app/app.py
    fi
else
    echo "✗ app directory does not exist"
fi

echo "=== VIRTUAL ENVIRONMENT ==="
if [ -d "venv" ]; then
    echo "✓ venv exists"
    source venv/bin/activate
    echo "Python in venv: $(which python)"
    echo "Pip packages:"
    pip list | grep -E "(Flask|gunicorn|Werkzeug)"
else
    echo "✗ venv does not exist"
    exit 1
fi

echo "=== TESTING PYTHON IMPORTS ==="
cd /home/ec2-user

# Test different import patterns
echo "Testing imports..."

if [ -f "run.py" ]; then
    echo "Testing: python -c 'import run'"
    python -c "import run; print('✓ run imported')" 2>&1 || echo "✗ run import failed"
    
    echo "Testing: python -c 'from run import app'"
    python -c "from run import app; print('✓ app from run imported')" 2>&1 || echo "✗ app from run import failed"
fi

if [ -f "app.py" ]; then
    echo "Testing: python -c 'import app'"
    python -c "import app; print('✓ app imported')" 2>&1 || echo "✗ app import failed"
fi

if [ -d "app" ] && [ -f "app/__init__.py" ]; then
    echo "Testing: python -c 'from app import app'"
    python -c "from app import app; print('✓ app from app package imported')" 2>&1 || echo "✗ app from app package import failed"
fi

echo "=== TESTING GUNICORN MANUALLY ==="
echo "Gunicorn version: $(gunicorn --version)"

# Test different module patterns
for module in "run:app" "app:app" "main:app" "app:create_app()"; do
    echo "Testing gunicorn with module: $module"
    timeout 3 gunicorn --check-config -w 1 -b 127.0.0.1:8001 $module 2>&1 || echo "✗ Failed with $module"
done

echo "=== TRYING TO START GUNICORN MANUALLY ==="
echo "Starting gunicorn manually for 3 seconds..."
timeout 3 gunicorn -w 1 -b 127.0.0.1:8001 run:app 2>&1 || echo "Manual gunicorn failed"

echo "=== SYSTEMD SERVICE CONTENT ==="
if [ -f "/etc/systemd/system/gamerhub.service" ]; then
    echo "Service file exists:"
    cat /etc/systemd/system/gamerhub.service
else
    echo "Service file does not exist"
fi

echo "=== ATTEMPTING TO START SERVICE ==="
sudo systemctl daemon-reload
sudo systemctl stop gamerhub 2>/dev/null || true
sleep 2
sudo systemctl start gamerhub

sleep 5

if systemctl is-active --quiet gamerhub; then
    echo "✓ Service started successfully"
    sudo systemctl status gamerhub --no-pager -l
else
    echo "✗ Service failed to start"
    echo "=== SERVICE STATUS ==="
    sudo systemctl status gamerhub --no-pager -l
    
    echo "=== JOURNAL LOGS ==="
    sudo journalctl -u gamerhub --no-pager -l --since "2 minutes ago"
    
    echo "=== CHECKING FOR PYTHON ERRORS ==="
    sudo journalctl -u gamerhub --no-pager --since "2 minutes ago" | grep -i "error\|traceback\|exception" || echo "No Python errors found in logs"
    
    exit 1
fi

echo "✓ Debugging completed!"
