#!/bin/bash

isExistApp="$(pgrep -f gunicorn)"
if [[ -n "$isExistApp" ]]; then
    echo "Stopping GamerHub service..."
    sudo systemctl stop gamerhub
else
    echo "GamerHub service not running."
fi
