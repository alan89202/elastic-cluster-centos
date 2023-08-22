#!/bin/bash

# Ensure the script stops on the first error
set -e

#Define ES variables
ES_KEYSTORE_PASS=$1
ES_CA_PASS=$2
INSTANCES_CERT_PASS=$3


# Update the system
echo "Updating the system..."
sudo yum -y update

# Install Java 11 OpenJDK Development Kit
echo "Installing Java 11 OpenJDK Development Kit..."
sudo yum -y install java-11-openjdk-devel

# Install other required packages
echo "Installing nano, lsof, nmon, unzip and openssl..."
sudo yum -y install nano lsof nmon unzip openssl

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
-e '/#*node\.name:/s/#*\([^:]*:\).*$/\1 '"$myhostname"'/' \
-e '/#*path\.data:/s/#*\([^:]*:\).*$/\1 \/app\/data1\/elasticsearch/' \
-e '/#*path\.logs:/s/#*\([^:]*:\).*$/\1 \/app\/logs\/elasticsearch/' \
-e '/#*network\.host:/s/#*\([^:]*:\).*$/\1 0.0.0.0/' \
-e "/#*discovery\.seed_hosts:/s/#*\([^:]*:\).*$/\1 $seed_hosts/" \
-e '/xpack.security.transport.ssl:/,/^\s*#/s/\(^\s*keystore.path:\).*/\1 certs\/'"$myhostname"'.p12/' \
-e '/xpack.security.transport.ssl:/,/^\s*#/s/\(^\s*truststore.path:\).*/\1 certs\/'"$myhostname"'.p12/' \
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
#Configure certificates
if [[ "$myhostname" == *"master-node-0"* ]]; 
  then
    # create elasticsearch CA
    sudo /usr/share/elasticsearch/bin/elasticsearch-certutil ca -s --pass $ES_CA_PASS --out cluster-demo-ca.p12
    # create instances file
    sudo cat > /usr/share/elasticsearch/instances.yml <<EOL
instances:
  - name: "master-node-0" 
    dns: 
      - "master-node-0.escluster.internal"
  - name: "master-node-1" 
    dns: 
      - "master-node-1.escluster.internal"
  - name: "master-node-2" 
    dns: 
      - "master-node-2.escluster.internal"
  - name: "hot-node-0" 
    dns: 
      - "hot-node-0.escluster.internal"
  - name: "hot-node-1" 
    dns: 
      - "hot-node-1.escluster.internal"
  - name: "warm-node" 
    dns: 
      - "warm-node.escluster.internal"
  - name: "kibana-node" 
    dns: 
      - "kibana-node.escluster.internal"
EOL

  #create certificates for each instance
  sudo /usr/share/elasticsearch/bin/elasticsearch-certutil cert --silent --in /usr/share/elasticsearch/instances.yml --out instances.zip --ca /usr/share/elasticsearch/cluster-demo-ca.p12 --pass $INSTANCES_CERT_PASS --ca-pass $ES_CA_PASS
  #create http certificates for each instance
  sudo /usr/share/elasticsearch/bin/elasticsearch-certutil http --silent --in /usr/share/elasticsearch/instances.yml --out instances_http.zip --ca /usr/share/elasticsearch/cluster-demo-ca.p12 --pass $INSTANCES_CERT_PASS --ca-pass $ES_CA_PASS
  #Upload Certificates to Cloud Storage
  sudo gsutil cp /usr/share/elasticsearch/cluster-demo-ca.p12 gs://elk_config_files/
  sudo gsutil cp /usr/share/elasticsearch/instances*.zip gs://elk_config_files/
  
  #Copy Certificates to Each Node
  sudo gsutil cp gs://elk_config_files/instances.zip /tmp
  sudo unzip /tmp/instances.zip -d /tmp/
  sudo cp /tmp/$HOSTNAME/$HOSTNAME.p12 /etc/elasticsearch/certs/
  
  sudo gsutil cp gs://elk_config_files/cluster-demo-ca.p12 /tmp
  sudo cp /tmp/cluster-demo-ca.p12 /etc/elasticsearch/certs/
  #sudo openssl pkcs12 -in /etc/elasticsearch/certs/cluster-demo-ca.p12 -clcerts -nokeys -out /etc/elasticsearch/certs/cluster-demo-ca.pem  

  #Copy http certificates to each node
  sudo gsutil cp gs://elk_config_files/instances_http.zip /tmp
  sudo unzip /tmp/instances_http.zip -d /tmp/
  
  #change files permissions
  sudo chown -Rf root:elasticsearch /etc/elasticsearch/*
  sudo chmod -Rf 770 /etc/elasticsearch/*

  #change the password of the elasticsearch keystore
  #echo $ES_KEYSTORE_PASS | sudo /usr/share/elasticsearch/bin/elasticsearch-keystore passwd -xf
  echo $INSTANCES_CERT_PASS | sudo /usr/share/elasticsearch/bin/elasticsearch-keystore add xpack.security.transport.ssl.keystore.secure_password -xf
  echo $INSTANCES_CERT_PASS | sudo /usr/share/elasticsearch/bin/elasticsearch-keystore add xpack.security.transport.ssl.truststore.secure_password -xf

  #Create the signal file
  CURRENT_DATETIME=$(date +"%Y%m%d%H%M")
  sudo echo "done" > /tmp/done_$CURRENT_DATETIME.txt
  sudo gsutil cp /tmp/done_$CURRENT_DATETIME.txt gs://elk_config_files/
  echo "Elasticsearch Installed"
else
  #Wait until node-0 finish
  BOOT_TIME=$(date -d "$(uptime -s)" +"%Y%m%d%H%M")
  while true; do
    LATEST_DONE_FILE=$(sudo gsutil ls gs://elk_config_files/done_*.txt | sort | tail -n 1)
    if [[ -z "$LATEST_DONE_FILE" ]]; then
        echo "Waiting until master-node-0 finish..."
        sleep 30
        continue
    fi
    LATEST_DONE_DATETIME=$(echo $LATEST_DONE_FILE | grep -oP '(?<=done_)\d+')
    # Compare dates between file and uptime command
    if [[ "$LATEST_DONE_DATETIME" -gt "$BOOT_TIME" ]]; then
        break
    else
        echo "Signal is from older execution. Waiting ..."
        sleep 30
    fi
  done
  #Copy Certificates to Each Node
  sudo gsutil cp gs://elk_config_files/instances.zip /tmp
  sudo unzip /tmp/instances.zip -d /tmp/
  sudo cp /tmp/$HOSTNAME/$HOSTNAME.p12 /etc/elasticsearch/certs/
  
  sudo gsutil cp gs://elk_config_files/cluster-demo-ca.p12 /tmp
  sudo cp /tmp/cluster-demo-ca.p12 /etc/elasticsearch/certs/
  #sudo openssl pkcs12 -in /etc/elasticsearch/certs/cluster-demo-ca.p12 -clcerts -nokeys -out /etc/elasticsearch/certs/cluster-demo-ca.pem
  
  #change files permissions
  sudo chown -Rf root:elasticsearch /etc/elasticsearch/*
  sudo chmod -Rf 770 /etc/elasticsearch/*

  #change the password of the elasticsearch keystore
  #echo $ES_KEYSTORE_PASS | sudo /usr/share/elasticsearch/bin/elasticsearch-keystore passwd -xf
  echo $INSTANCES_CERT_PASS | sudo /usr/share/elasticsearch/bin/elasticsearch-keystore add xpack.security.transport.ssl.keystore.secure_password -xf
  echo $INSTANCES_CERT_PASS | sudo /usr/share/elasticsearch/bin/elasticsearch-keystore add xpack.security.transport.ssl.truststore.secure_password -xf
  echo "Elasticsearch Installed"
fi





