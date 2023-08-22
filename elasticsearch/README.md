# Elasticsearch TLS Configuration Guide

This guide will walk you through the process of generating certificates and configuring your Elasticsearch nodes for secured communication.

## 1. Execute on the Primary Node

First, you'll need to create a certificate authority (CA) on the primary node.

```bash
/usr/share/elasticsearch/bin/elasticsearch-certutil ca -s --pass "" --out elastic-stack-ca.p12
```

## 2. Create the `instances.yml` File

This file will define your Elasticsearch nodes and their associated DNS names.
```bash
vim /usr/share/elasticsearch/instances.yml
```

Add the following content:

```yaml
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
```

## 3. Generate Certificates

Use the instances.yml file you've just created to generate the necessary certificates.
```bash
/usr/share/elasticsearch/bin/elasticsearch-certutil cert --silent --in /usr/share/elasticsearch/instances.yml --out instances.zip --ca /usr/share/elasticsearch/elastic-stack-ca.p12 --pass "" --ca-pass ""
```

## 4. Upload Certificates to Cloud Storage

If you're using gsutil for cloud storage, you can upload the instances.zip file as follows:
```bash
gsutil cp /usr/share/elasticsearch/instances.zip gs://elk_config_files/
```

## 5. Copy Certificates to Each Node

On each node, pull the certificates from the cloud storage and extract them.

```bash
gsutil cp gs://elk_config_files/instances.zip /tmp
unzip /tmp/instances.zip -d /tmp/
cp /tmp/$HOSTNAME/$HOSTNAME.p12 /etc/elasticsearch/certs/
```

## 6. Set Proper Permissions

Ensure the certificates have the right ownership and permissions.

```bash
chown -Rf root:elasticsearch /etc/elasticsearch/*
chmod -Rf 770 /etc/elasticsearch/*
```

## 7. Update Certificate Passwords

Finally, update the passwords for the Elasticsearch keystore.

```bash
/usr/share/elasticsearch/bin/elasticsearch-keystore add xpack.security.transport.ssl.keystore.secure_password
/usr/share/elasticsearch/bin/elasticsearch-keystore add xpack.security.transport.ssl.truststore.secure_password

```
