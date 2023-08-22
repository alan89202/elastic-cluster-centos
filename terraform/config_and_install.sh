#Save terraform variables
ES_KEYSTORE_PASS=$1
ES_CA_PASS=$2
INSTANCES_CERT_PASS=$3

# Copy disk_setup.sh from the Cloud Storage bucket and set execution permissions
gsutil cp gs://elk_config_files/disk_setup.sh /tmp/
chmod +x /tmp/disk_setup.sh

# Execute disk_setup.sh
/tmp/disk_setup.sh

# Get the hostname of the current instance
HOSTNAME=$(hostname)

# Check if the hostname contains the word 'kibana'
if echo $HOSTNAME | grep -q 'kibana'; then
  # If 'kibana' is in the hostname, copy and execute basic_install_kib.sh
  #gsutil cp gs://elk_config_files/basic_install_kib.sh /tmp/
  #chmod +x /tmp/basic_install_kib.sh
  #/tmp/basic_install_kib.sh
  echo "kibana"
else
  # If 'kibana' is not in the hostname, copy and execute basic_install_es.sh
  gsutil cp gs://elk_config_files/basic_install_es.sh /tmp/
  chmod +x /tmp/basic_install_es.sh
  /tmp/basic_install_es.sh $ES_KEYSTORE_PASS $ES_CA_PASS $INSTANCES_CERT_PASS
fi

