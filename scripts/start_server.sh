#!/bin/bash

# Reload systemd in case the service file was updated
sudo systemctl daemon-reexec
sudo systemctl daemon-reload

# Start and enable the Flask Gunicorn service
sudo systemctl start gamerhub
sudo systemctl enable gamerhub
