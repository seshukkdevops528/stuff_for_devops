#!/bin/bash

set -e

SONAR_VERSION="10.5.1.90531"
SONAR_USER="sonar"
INSTALL_DIR="/opt"
SONAR_HOME="$INSTALL_DIR/sonarqube"

echo "Updating system..."
sudo dnf update -y

echo "Installing required packages..."
sudo dnf install -y java-17-openjdk wget unzip postgresql-server postgresql-contrib

echo "Initializing PostgreSQL..."
sudo postgresql-setup --initdb

echo "Starting PostgreSQL..."
sudo systemctl enable postgresql
sudo systemctl start postgresql

echo "Setting PostgreSQL password and creating Sonar DB..."
sudo -u postgres psql <<EOF
ALTER USER postgres WITH PASSWORD 'StrongPassword';
CREATE USER sonar WITH ENCRYPTED PASSWORD 'sonar';
CREATE DATABASE sonarqube OWNER sonar;
GRANT ALL PRIVILEGES ON DATABASE sonarqube TO sonar;
EOF

echo "Creating sonar user..."
if id "$SONAR_USER" &>/dev/null; then
    echo "User already exists"
else
    sudo useradd -r -m -d $SONAR_HOME -s /bin/bash $SONAR_USER
fi

cd $INSTALL_DIR

echo "Downloading SonarQube..."
sudo wget https://binaries.sonarsource.com/Distribution/sonarqube/sonarqube-${SONAR_VERSION}.zip

echo "Extracting SonarQube..."
sudo unzip sonarqube-${SONAR_VERSION}.zip

echo "Renaming directory..."
sudo mv sonarqube-${SONAR_VERSION} sonarqube

echo "Setting permissions..."
sudo chown -R $SONAR_USER:$SONAR_USER $SONAR_HOME

echo "Configuring SonarQube database..."
sudo sed -i 's|#sonar.jdbc.username=|sonar.jdbc.username=sonar|' $SONAR_HOME/conf/sonar.properties
sudo sed -i 's|#sonar.jdbc.password=|sonar.jdbc.password=sonar|' $SONAR_HOME/conf/sonar.properties
sudo sed -i 's|#sonar.jdbc.url=jdbc:postgresql://localhost/sonarqube|sonar.jdbc.url=jdbc:postgresql://localhost:5432/sonarqube|' $SONAR_HOME/conf/sonar.properties

echo "Configuring system limits..."
echo "vm.max_map_count=262144" | sudo tee -a /etc/sysctl.conf
echo "fs.file-max=65536" | sudo tee -a /etc/sysctl.conf

sudo sysctl -p

echo "Setting user limits..."
echo "$SONAR_USER   -   nofile   65536" | sudo tee -a /etc/security/limits.conf
echo "$SONAR_USER   -   nproc    4096" | sudo tee -a /etc/security/limits.conf

echo "Creating systemd service..."
sudo bash -c 'cat > /etc/systemd/system/sonarqube.service <<EOF
[Unit]
Description=SonarQube service
After=syslog.target network.target

[Service]
Type=forking
User=sonar
Group=sonar
ExecStart=/opt/sonarqube/bin/linux-x86-64/sonar.sh start
ExecStop=/opt/sonarqube/bin/linux-x86-64/sonar.sh stop
Restart=always
LimitNOFILE=65536
LimitNPROC=4096

[Install]
WantedBy=multi-user.target
EOF'

echo "Reloading systemd..."
sudo systemctl daemon-reexec
sudo systemctl daemon-reload

echo "Starting SonarQube..."
sudo systemctl enable sonarqube
sudo systemctl start sonarqube

echo "Checking SonarQube status..."
sudo systemctl status sonarqube --no-pager

echo "======================================"
echo "SonarQube installation completed!"
echo "Access SonarQube at: http://<your-server-ip>:9000"
echo "Default login: admin / admin"
echo "======================================"
