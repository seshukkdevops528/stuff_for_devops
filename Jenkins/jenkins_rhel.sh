#!/bin/bash

set -e

echo "Updating system packages..."
if [ -f /etc/debian_version ]; then
    sudo apt update -y
    sudo apt upgrade -y
elif [ -f /etc/redhat-release ]; then
    sudo yum update -y
fi

echo "Installing Java (required for Jenkins)..."
if [ -f /etc/debian_version ]; then
    sudo apt install -y openjdk-17-jdk
elif [ -f /etc/redhat-release ]; then
    sudo yum install -y java-17-openjdk
fi

echo "Installing Git..."
if [ -f /etc/debian_version ]; then
    sudo apt install -y git
elif [ -f /etc/redhat-release ]; then
    sudo yum install -y git
fi

echo "Adding Jenkins repository..."
if [ -f /etc/debian_version ]; then
    curl -fsSL https://pkg.jenkins.io/debian/jenkins.io-2023.key | sudo tee \
      /usr/share/keyrings/jenkins-keyring.asc > /dev/null

    echo "deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc] \
      https://pkg.jenkins.io/debian binary/" | sudo tee \
      /etc/apt/sources.list.d/jenkins.list > /dev/null

    sudo apt update -y
    sudo apt install -y jenkins

elif [ -f /etc/redhat-release ]; then
    sudo wget -O /etc/yum.repos.d/jenkins.repo \
      https://pkg.jenkins.io/redhat-stable/jenkins.repo

    sudo rpm --import https://pkg.jenkins.io/redhat-stable/jenkins.io-2023.key
    sudo yum install -y jenkins
fi

echo "Starting Jenkins service..."
sudo systemctl daemon-reexec
sudo systemctl enable jenkins
sudo systemctl start jenkins

echo "Checking Jenkins status..."
sudo systemctl status jenkins --no-pager

echo "Opening firewall port (if applicable)..."
if command -v ufw >/dev/null 2>&1; then
    sudo ufw allow 8080
    sudo ufw reload
elif command -v firewall-cmd >/dev/null 2>&1; then
    sudo firewall-cmd --permanent --add-port=8080/tcp
    sudo firewall-cmd --reload
fi

echo "Fetching initial admin password..."
sudo cat /var/lib/jenkins/secrets/initialAdminPassword

echo ""
echo "Jenkins installation completed!"
echo "Access Jenkins at: http://<your-server-ip>:8080"
