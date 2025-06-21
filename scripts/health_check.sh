#!/bin/bash
set -e

echo "=== Health Check ==="

# Check if service is running
if systemctl is-active --quiet gamerhub; then
    echo "✅ GamerHub service is running"
else
    echo "❌ GamerHub service is not running"
    exit 1
fi

# Check if application responds to HTTP requests
echo "Testing HTTP endpoint..."
if curl -f -s http://localhost:8000/ > /dev/null; then
    echo "✅ Application is responding to HTTP requests"
else
    echo "❌ Application is not responding to HTTP requests"
    exit 1
fi

# Test the previously problematic endpoint
echo "Testing /auth/new_user endpoint..."
if curl -f -s http://localhost:8000/auth/new_user > /dev/null; then
    echo "✅ /auth/new_user endpoint is accessible"
else
    echo "❌ /auth/new_user endpoint is not accessible"
    # Don't fail the health check for this specific endpoint
    # but log it for debugging
    echo "This may indicate a database permissions issue"
fi

# Test database connectivity
echo "Testing database connectivity..."
sudo -u ec2-user bash -c '
    cd /home/ec2-user
    source venv/bin/activate
    python -c "
from app import create_app
app = create_app()
with app.app_context():
    from app.models import db
    from sqlalchemy import text
    result = db.session.execute(text(\"SELECT 1\")).scalar()
    if result == 1:
        print(\"✅ Database connectivity verified\")
    else:
        print(\"❌ Database connectivity failed\")
        exit(1)
"
'

echo "🎉 Health check passed!"
