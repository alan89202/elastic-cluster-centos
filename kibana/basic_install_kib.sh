#!/bin/bash

ES_KEYSTORE_PASS=$1
ES_CA_PASS=$2
INSTANCES_CERT_PASS=$3
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
sudo mkdir /etc/kibana/config
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
-e '/#*server\.host:/s/#*\([^:]*:\).*$/\1 '"$myhostname"'.escluster.internal/' \
-e '/#*server\.name:/s/#*\([^:]*:\).*$/\1 '"$myhostname"'/' \
-e '/#*path\.data:/s/#*\([^:]*:\).*$/\1 \/app\/data1\/kibana/' \
-e '/appenders:/,/type: json/ { s#fileName: /var/log/kibana/kibana.log#fileName: /app/logs/kibana/kibana.log#g }' \
$FILE
echo -e "\n# This configures Kibana to trust a specific Certificate Authority for connections to Elasticsearch\nelasticsearch.ssl.certificateAuthorities: [ \"/etc/kibana/config/elasticsearch-ca.pem\" ]" | sudo tee -a $FILE > /dev/null
echo -e "\n \nelasticsearch.ssl.verificationMode: certificate\nserver.ssl.enabled: true\nserver.ssl.keystore.path: \"/etc/kibana/certs/http.p12\""

es_nodes="["
for i in $(seq 0 $((count-1))); do
  es_nodes+="\"https://hot-node-$i.$DOMAIN\""
  [ $i -lt $((count-1)) ] && es_nodes+=", "
done
es_nodes+="]"

sudo sed -i 's|^#*elasticsearch\.hosts:.*$|elasticsearch.hosts: '"$es_nodes"'|' $FILE

#Change keystore passwords
echo $INSTANCES_CERT_PASS | sudo /usr/share/kibana/bin/kibana-keystore add server.ssl.keystore.password -xf

#Create script to finish HTTP certificate configurations
sudo cat > /tmp/http_cert_config.sh <<EOL
#!/bin/bash

# Ensure the script stops on the first error
set -e

#Copy Certificates to Each Node
sudo gsutil cp gs://elk_config_files/instances_http.zip /tmp
sudo unzip /tmp/instances_http.zip -d /tmp/
sudo cp -f /tmp/kibana/elasticsearch-ca.pem /etc/kibana/config/

#change files permissions
sudo chown -Rf root:kibana /etc/kibana/*
sudo chmod -Rf 770 /etc/kibana/*
EOL

sudo chmod -Rf 770 /tmp/http_cert_config.sh

