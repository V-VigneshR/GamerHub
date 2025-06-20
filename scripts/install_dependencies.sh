#!/bin/bash
sudo yum update -y
sudo yum install -y python3 unzip

# Unpack the app
cd /home/ec2-user
unzip flask-app.zip

# Install requirements
pip3 install -r requirements.txt

# Optional: Create a systemd service file for gunicorn (like how Apache is configured)
sudo cat << EOF > /etc/systemd/system/gamerhub.service
[Unit]
Description=GamerHub Flask App
After=network.target

[Service]
User=ec2-user
WorkingDirectory=/home/ec2-user
ExecStart=/usr/local/bin/gunicorn -w 3 -b 0.0.0.0:80 app:app
Restart=always

[Install]
WantedBy=multi-user.target
EOF

# Enable and start the Flask app service
sudo systemctl daemon-reexec
sudo systemctl daemon-reload
sudo systemctl enable gamerhub
sudo systemctl start gamerhub
