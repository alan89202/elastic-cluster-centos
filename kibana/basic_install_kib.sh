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

# Create and update the Kibana repo file
echo "Updating kibana repository settings..."
sudo bash -c 'cat <<EOL > /etc/yum.repos.d/kibana.repo
[kibana-8.x]
name=Kibana repository for 8.x packages
baseurl=https://artifacts.elastic.co/packages/8.x/yum
gpgcheck=1
gpgkey=https://artifacts.elastic.co/GPG-KEY-elasticsearch
enabled=1
autorefresh=1
type=rpm-md
EOL'


# Install kibana
echo "Installing Kibana..."
sudo yum -y install kibana

# Create kibana data directory
echo "Setting up kibana data directory..."
sudo mkdir -p /app/data1/kibana
sudo chown kibana:kibana /app/data1/kibana
sudo chmod 770 /app/data1/kibana/

# Create kibana logs directory
echo "Setting up kibana logs directory..."
sudo mkdir -p /app/logs/kibana
sudo chown kibana:kibana /app/logs/kibana
sudo chmod 770 /app/logs/kibana/

sudo systemctl daemon-reload
sudo systemctl enable kibana.service

#Configuring kibana.yml
DOMAIN="escluster.internal"
FILE="/etc/kibana/kibana.yml"
sudo cp -p $FILE $FILE"_backup"

#counting hot nodes
count=0
myhostname=$(hostname)

for i in {0..100}; do
  if [[ "hot-node-$i.$DOMAIN" == "$myhostname" ]] || ping -c 1 -W 1 "hot-node-$i.$DOMAIN" &> /dev/null; then
    count=$((count+1))
  fi
done



#Replace arguments
sudo sed -i \
-e '/#*server\.port:/s/#*\([^:]*:\).*$/\1 5601/' \
-e '/#*server\.host:/s/#*\([^:]*:\).*$/\1 $HOSTNAME/' \
-e '/#*path\.data:/s/#*\([^:]*:\).*$/\1 \/app\/data1\/kibana/' \
-e '/appenders:/,/type: json/ { s#fileName: /var/log/kibana/kibana.log#fileName: /app/logs/kibana/kibana.log#g }' \
$FILE

es_nodes="["
for i in $(seq 0 $((count-1))); do
  es_nodes+="\"https://hot-node-$i.$DOMAIN\""
  [ $i -lt $((count-1)) ] && es_nodes+=", "
done
es_nodes+="]"

sudo sed -i 's|^#*elasticsearch\.hosts:.*$|elasticsearch.hosts: '"$es_nodes"'|' $FILE
