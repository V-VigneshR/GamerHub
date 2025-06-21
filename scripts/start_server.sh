#!/bin/bash
set -e

echo "=== Starting GamerHub Server ==="

# Navigate to application directory
cd /home/ec2-user

# Initialize database as ec2-user (this is the key fix!)
echo "Initializing database as ec2-user..."
sudo -u ec2-user bash -c '
    cd /home/ec2-user
    source venv/bin/activate
    python init_db.py
'

# Test application startup
echo "Testing application startup..."
sudo -u ec2-user bash -c '
    cd /home/ec2-user
    source venv/bin/activate
    timeout 10s python -c "
from app import create_app
app = create_app()
print(\"✓ Application can be created successfully\")
with app.app_context():
    from app.models import db
    from sqlalchemy import text
    result = db.session.execute(text(\"SELECT COUNT(*) FROM user\")).scalar()
    print(f\"✓ Database connection verified (users: {result})\")
"
'

# Start the systemd service
echo "Starting GamerHub systemd service..."
systemctl start gamerhub

# Enable service to start on boot
systemctl enable gamerhub

# Wait for service to start
sleep 5

# Verify service is running
if systemctl is-active --quiet gamerhub; then
    echo "✅ GamerHub service started successfully"
    
    # Test the problematic endpoint
    echo "Testing /auth/new_user endpoint..."
    if curl -f -s http://localhost:8000/auth/new_user > /dev/null; then
        echo "✅ /auth/new_user is accessible"
    else
        echo "⚠️  /auth/new_user might have issues - check application logs"
        # Show recent logs for debugging
        journalctl -u gamerhub --no-pager -l | tail -5
    fi
    
    echo "🎉 Server started successfully!"
    echo "Application is accessible at: http://localhost:8000"
    
else
    echo "❌ Service failed to start"
    echo "Checking service status..."
    systemctl status gamerhub --no-pager -l
    echo "Checking recent logs..."
    journalctl -u gamerhub --no-pager -l | tail -10
    exit 1
fi
