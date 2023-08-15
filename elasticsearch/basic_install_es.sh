#!/bin/bash

# Ensure the script stops on the first error
set -e

# Update the system
echo "Updating the system..."
sudo yum -y update

# Install Java 11 OpenJDK Development Kit
echo "Installing Java 11 OpenJDK Development Kit..."
sudo yum -y install java-11-openjdk-devel

# Install other required packages
echo "Installing nano, lsof, nmon, and unzip..."
sudo yum -y install nano lsof nmon unzip

# Import GPG key for Elasticsearch
echo "Importing GPG key for Elasticsearch..."
sudo rpm --import https://artifacts.elastic.co/GPG-KEY-elasticsearch

# Create and update the Elasticsearch repo file
echo "Updating Elasticsearch repository settings..."
sudo bash -c 'cat <<EOL > /etc/yum.repos.d/elasticsearch.repo
[elasticsearch]
name=Elasticsearch repository for 8.x packages
baseurl=https://artifacts.elastic.co/packages/8.x/yum
gpgcheck=1
gpgkey=https://artifacts.elastic.co/GPG-KEY-elasticsearch
enabled=0
autorefresh=1
type=rpm-md
EOL'


# Install Elasticsearch
echo "Installing Elasticsearch..."
sudo yum -y install --enablerepo=elasticsearch elasticsearch

# Create Elasticsearch data directory
echo "Setting up Elasticsearch data directory..."
sudo mkdir -p /app/data1/elasticsearch
sudo chown elasticsearch:elasticsearch /app/data1/elasticsearch
sudo chmod 770 /app/data1/elasticsearch/

# Create Elasticsearch logs directory
echo "Setting up Elasticsearch logs directory..."
sudo mkdir -p /app/logs/elasticsearch
sudo chown elasticsearch:elasticsearch /app/logs/elasticsearch
sudo chmod 770 /app/logs/elasticsearch/

sudo systemctl daemon-reload
sudo systemctl enable elasticsearch.service

#Configuring elasticsearch.yml

FILE="/etc/elasticsearch/elasticsearch.yml"

sudo cp -p $FILE "$FILE_backup"

#Replace arguments
sudo sed -i \
-e '/#*cluster\.name:/s/#*\([^:]*:\).*$/\1 cluster-demo/' \
-e '/#*node\.name:/s/#*\([^:]*:\).*$/\1 $HOSTNAME/' \
-e '/#*path\.data:/s/#*\([^:]*:\).*$/\1 \/app\/data1\/elasticsearch/' \
-e '/#*path\.logs:/s/#*\([^:]*:\).*$/\1 \/app\/logs\/elasticsearch/' \
# Añade más reemplazos en nuevas líneas si es necesario
$FILE





