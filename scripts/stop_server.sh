#!/bin/bash
set -e

echo "Stopping GamerHub service..."

if systemctl is-active --quiet gamerhub; then
    echo "Service is running, stopping it..."
    sudo systemctl stop gamerhub
    echo "Service stopped successfully"
else
    echo "Service is not running or doesn't exist"
fi

echo "Cleaning up any remaining gunicorn processes..."
pkill -f "gunicorn.*run:app" || echo "No gunicorn processes found"

echo "Stop server completed!"
