#!/bin/bash

# Exit immediately if a command fails
set -e

NEXUS_VERSION="3.68.1-02"
NEXUS_USER="nexus"
INSTALL_DIR="/opt"
NEXUS_HOME="$INSTALL_DIR/nexus"
NEXUS_DATA="$INSTALL_DIR/sonatype-work"

echo "Updating system..."
sudo dnf update -y

echo "Installing required packages..."
sudo dnf install -y java-17-openjdk wget tar

echo "Creating nexus user..."
if id "$NEXUS_USER" &>/dev/null; then
    echo "User already exists"
else
    sudo useradd -r -m -d $NEXUS_HOME -s /bin/bash $NEXUS_USER
fi

cd $INSTALL_DIR

echo "Downloading Nexus..."
sudo wget https://download.sonatype.com/nexus/3/nexus-${NEXUS_VERSION}-unix.tar.gz

echo "Extracting Nexus..."
sudo tar -xvzf nexus-${NEXUS_VERSION}-unix.tar.gz

echo "Renaming directory..."
sudo mv nexus-${NEXUS_VERSION} nexus

echo "Setting permissions..."
sudo chown -R $NEXUS_USER:$NEXUS_USER $NEXUS_HOME
sudo chown -R $NEXUS_USER:$NEXUS_USER $NEXUS_DATA

echo "Configuring Nexus to run as service user..."
echo 'run_as_user="nexus"' | sudo tee $NEXUS_HOME/bin/nexus.rc

echo "Creating systemd service file..."
sudo bash -c 'cat > /etc/systemd/system/nexus.service <<EOF
[Unit]
Description=Nexus Repository Manager
After=network.target

[Service]
Type=forking
LimitNOFILE=65536
User=nexus
Group=nexus
ExecStart=/opt/nexus/bin/nexus start
ExecStop=/opt/nexus/bin/nexus stop
Restart=on-abort

[Install]
WantedBy=multi-user.target
EOF'

echo "Reloading systemd..."
sudo systemctl daemon-reexec
sudo systemctl daemon-reload

echo "Enabling Nexus service..."
sudo systemctl enable nexus

echo "Starting Nexus..."
sudo systemctl start nexus

echo "Checking Nexus status..."
sudo systemctl status nexus --no-pager

echo "======================================"
echo "Nexus installation completed!"
echo "Access Nexus at: http://<your-server-ip>:8081"
echo "======================================"

echo "Initial admin password:"
sudo cat /opt/sonatype-work/nexus3/admin.password || true
