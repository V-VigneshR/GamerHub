#!/bin/bash
set -e
echo "Starting GamerHub service..."

cd /home/ec2-user
source venv/bin/activate

echo "=== Testing imports ==="
python -c "import sqlalchemy; print(f'SQLAlchemy version: {sqlalchemy.__version__}')"
python -c "from flask_sqlalchemy import SQLAlchemy; print('Flask-SQLAlchemy OK')"
python -c "from app import create_app, db; print('App imports OK')"
python -c "from app import create_app, db; app = create_app(); print('App creation OK')"

echo "=== Testing gunicorn config ==="
timeout 3 gunicorn --check-config -w 1 -b 127.0.0.1:8001 run:app || {
    echo "Gunicorn config test failed"
    exit 1
}

echo "=== Starting service ==="
sudo systemctl daemon-reload
sudo systemctl stop gamerhub 2>/dev/null || true
sleep 2
sudo systemctl start gamerhub
sleep 5

if systemctl is-active --quiet gamerhub; then
    echo "✓ GamerHub service started successfully!"
    sudo systemctl status gamerhub --no-pager -l

    # Test HTTP response
    if curl -f -s http://localhost:8000/ > /dev/null; then
        echo "✓ Service is responding to HTTP requests"
    else
        echo "⚠ Service running but no HTTP response (might be normal)"
    fi
else
    echo "✗ Service failed to start"
    sudo systemctl status gamerhub --no-pager -l
    echo "=== Recent logs ==="
    sudo journalctl -u gamerhub --no-pager -l --since "1 minute ago"
    exit 1
fi

echo "✓ Server startup completed!"
