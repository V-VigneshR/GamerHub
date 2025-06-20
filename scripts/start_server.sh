#!/bin/bash
set -e  # Exit on any error

echo "Starting GamerHub service..."

# Reload systemd in case the service file was updated
sudo systemctl daemon-reexec
sudo systemctl daemon-reload

# Start the Flask Gunicorn service
echo "Starting gamerhub service..."
sudo systemctl start gamerhub

# Enable it to start on boot
sudo systemctl enable gamerhub

# Wait a moment and check status
sleep 3

# Check if service is running
if systemctl is-active --quiet gamerhub; then
    echo "GamerHub service started successfully!"
    sudo systemctl status gamerhub --no-pager -l
else
    echo "Failed to start GamerHub service. Checking logs..."
    sudo systemctl status gamerhub --no-pager -l
    sudo journalctl -u gamerhub --no-pager -l --since "1 minute ago"
    exit 1
fi

echo "Server startup completed!"