#!/bin/bash
SERVICE="gamerhub"
if systemctl is-active --quiet $SERVICE; then
  echo "Stopping $SERVICE..."
  sudo systemctl stop $SERVICE
else
  echo "$SERVICE is not running."
fi