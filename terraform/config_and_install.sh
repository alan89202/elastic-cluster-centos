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
  /tmp/basic_install_es.sh
fi

