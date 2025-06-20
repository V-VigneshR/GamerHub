#!/bin/bash
sudo yum update -y
sudo yum install -y python3 unzip

# Install requirements will happen after unzip in start_server.sh
echo "Dependencies installed."
