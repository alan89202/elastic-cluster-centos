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
DOMAIN="escluster.internal"
FILE="/etc/elasticsearch/elasticsearch.yml"
sudo cp -p $FILE $FILE"_backup"

#counting master nodes
count=0
myhostname=$(hostname)

for i in {0..100}; do
  if [[ "master-node-$i.$DOMAIN" == "$myhostname" ]] || ping -c 1 -W 1 "master-node-$i.$DOMAIN" &> /dev/null; then
    count=$((count+1))
  fi
done

#Create seed hosts
seed_hosts="["
for i in $(seq 0 $((count-1))); do
  seed_hosts+="\"master-node-$i.$DOMAIN\""
  [ $i -lt $((count-1)) ] && seed_hosts+=", "
done
seed_hosts+="]"

#Replace arguments
sudo sed -i \
-e '/#*cluster\.name:/s/#*\([^:]*:\).*$/\1 cluster-demo/' \
-e '/#*node\.name:/s/#*\([^:]*:\).*$/\1 $HOSTNAME/' \
-e '/#*path\.data:/s/#*\([^:]*:\).*$/\1 \/app\/data1\/elasticsearch/' \
-e '/#*path\.logs:/s/#*\([^:]*:\).*$/\1 \/app\/logs\/elasticsearch/' \
-e '/#*network\.host:/s/#*\([^:]*:\).*$/\1 0.0.0.0/' \
-e "/#*discovery\.seed_hosts:/s/#*\([^:]*:\).*$/\1 $seed_hosts/" \
$FILE

#Replace only master configs

if [[ "$myhostname" == *"master"* ]]; 
  then
    initial_master_nodes="["
    for i in $(seq 0 $((count-1))); do
      initial_master_nodes+="\"master-node-$i\""
      [ $i -lt $((count-1)) ] && initial_master_nodes+=", "
    done
    initial_master_nodes+="]"
    
    sudo sed -i "0,/cluster\.initial_master_nodes:/s/.*cluster\.initial_master_nodes:.*/cluster.initial_master_nodes: $initial_master_nodes/" $FILE
    sudo sed -i "1,/cluster\.initial_master_nodes:/!s/^cluster\.initial_master_nodes/#&/" $FILE
    echo -e "\n#Node Role\nnode.roles: [ master ]" | sudo tee -a $FILE > /dev/null

#Replace only hot configs

elif [[ "$myhostname" == *"hot"* ]];
  then
    sudo sed -i "1,/cluster\.initial_master_nodes:/!s/^cluster\.initial_master_nodes/#&/" $FILE  
    echo -e "\n#Node Role\nnode.roles: [ \"data_content\", \"data_hot\", \"ingest\" ]" | sudo tee -a $FILE > /dev/null

#Replace only warm configs

elif [[ "$myhostname" == *"warm"* ]];
  then
    sudo sed -i "1,/cluster\.initial_master_nodes:/!s/^cluster\.initial_master_nodes/#&/" $FILE
    echo -e "\n#Node Role\nnode.roles: [ \"data_warm\" ]" | sudo tee -a $FILE > /dev/null
fi






