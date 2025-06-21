#!/bin/bash
set -e

echo "=== Installing Dependencies ==="

# Navigate to application directory
cd /home/ec2-user

# Create virtual environment if it doesn't exist
if [ ! -d "venv" ]; then
    echo "Creating virtual environment..."
    python3 -m venv venv
fi

# Activate virtual environment
echo "Activating virtual environment..."
source venv/bin/activate

# Upgrade pip
echo "Upgrading pip..."
pip install --upgrade pip

# Install dependencies
echo "Installing Python dependencies..."
pip install -r requirements.txt

# Fix ownership and permissions for all files
echo "Fixing ownership and permissions..."
chown -R ec2-user:ec2-user /home/ec2-user/
chmod -R 755 /home/ec2-user/

# Create instance directory with proper permissions
echo "Setting up instance directory..."
sudo -u ec2-user mkdir -p /home/ec2-user/instance
sudo -u ec2-user chmod 755 /home/ec2-user/instance

# Make init_db.py executable
if [ -f "/home/ec2-user/init_db.py" ]; then
    chmod +x /home/ec2-user/init_db.py
    chown ec2-user:ec2-user /home/ec2-user/init_db.py
fi

echo "✅ Dependencies installed successfully"
