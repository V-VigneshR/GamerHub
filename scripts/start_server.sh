#!/bin/bash
set -e

echo "Starting GamerHub service..."

sudo systemctl daemon-reexec
sudo systemctl daemon-reload

echo "Starting gamerhub service..."
sudo systemctl start gamerhub
sudo systemctl enable gamerhub

sleep 3

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
