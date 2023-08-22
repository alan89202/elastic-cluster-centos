# Google configuration
provider "google" {
  credentials = file(var.credentials)
  project     = var.project_name
}

# Master Logs disks creation
resource "google_compute_disk" "master_logs_disks" {
  count = var.master_count
  name  = "master-logs-disk-${count.index}"
  type  = "pd-standard"
  size  = 30
  zone = var.zone[count.index]
}

# master nodes disk creation
resource "google_compute_disk" "master_disks" {
  count = var.master_count
  name  = "master-disk-${count.index}"
  type  = "pd-standard"
  size  = 50
  zone = var.zone[count.index]
}

# VM instances creation - master nodes
resource "google_compute_instance" "master_nodes" {
  service_account {
    email  = "terraform-service-account@alvaro-demo-elastic-000001.iam.gserviceaccount.com"
    scopes = ["https://www.googleapis.com/auth/devstorage.read_write"]
  }
  count        = var.master_count
  name         = "master-node-${count.index}"
  machine_type = var.master_machine_type
  tags = var.elastic_tags 
  allow_stopping_for_update = true
  zone = var.zone[count.index]

  boot_disk {
    initialize_params {
      image = var.image
      size  = 50
      type  = "pd-standard"
    }
  }

  network_interface {
    access_config {
      network_tier = "PREMIUM"
    }

    subnetwork = "projects/alvaro-demo-elastic-000001/regions/${var.region}/subnetworks/default"
  }

  attached_disk {
    source = google_compute_disk.master_disks[count.index].self_link
  }
  attached_disk {
    source = google_compute_disk.master_logs_disks[count.index].self_link
  }
  metadata_startup_script = templatefile("${path.module}/config_and_install.tftpl", {
    es_keystore_pass = var.es_keystore_pass
    es_ca_pass = var.es_ca_pass
    instances_cert_pass = var.instances_cert_pass
  })
}

# Hot Logs disks creation
resource "google_compute_disk" "hot_logs_disks" {
  count = var.hot_count
  name  = "hot-logs-disk-${count.index}"
  type  = "pd-standard"
  size  = 30
  zone = var.zone[count.index]
}

# hot nodes disk creation
resource "google_compute_disk" "hot_disks" {
  count = var.hot_count
  name  = "hot-disk-${count.index}"
  type  = "pd-ssd"
  size  = 200
  zone = var.zone[count.index]
}

# VM instances creation - hot nodes
resource "google_compute_instance" "hot_nodes" {
  service_account {
    email  = "terraform-service-account@alvaro-demo-elastic-000001.iam.gserviceaccount.com"
    scopes = ["https://www.googleapis.com/auth/devstorage.read_write"] 
  }
  count        = var.hot_count
  name         = "hot-node-${count.index}"
  machine_type = var.hot_machine_type
  tags = var.elastic_tags 
  allow_stopping_for_update = true
  zone = var.zone[count.index]

  boot_disk {
    initialize_params {
      image = var.image
      size  = 50
      type  = "pd-standard"
    }
  }

  network_interface {
    access_config {
      network_tier = "PREMIUM"
    }

    subnetwork = "projects/alvaro-demo-elastic-000001/regions/${var.region}/subnetworks/default"
  }

  attached_disk {
    source = google_compute_disk.hot_disks[count.index].self_link
  }
  attached_disk {
    source = google_compute_disk.hot_logs_disks[count.index].self_link
  }
  metadata_startup_script = templatefile("${path.module}/config_and_install.tftpl", {
    es_keystore_pass = var.es_keystore_pass
    es_ca_pass = var.es_ca_pass
    instances_cert_pass = var.instances_cert_pass
  })
}

# warm Logs disks creation
resource "google_compute_disk" "warm_logs_disks" {
  count = var.warm_count
  name  = "warm-logs-disk-${count.index}"
  type  = "pd-standard"
  size  = 30
  zone = var.zone[count.index + var.hot_count] 
}

# warm node disk creation
resource "google_compute_disk" "warm_disk" {
  count = var.warm_count
  name = "warm-disk"
  type = "pd-standard"
  size = 1000
  zone = var.zone[count.index + var.hot_count] 
}

# VM instances creation - warm nodes
resource "google_compute_instance" "warm_node" {
  service_account {
    email  = "terraform-service-account@alvaro-demo-elastic-000001.iam.gserviceaccount.com"
    scopes = ["https://www.googleapis.com/auth/devstorage.read_write"]
  }
  count = var.warm_count
  name = "warm-node"
  machine_type = var.warm_machine_type
  tags = var.elastic_tags
  allow_stopping_for_update = true
  zone = var.zone[count.index + var.hot_count]  

  boot_disk {
    initialize_params {
      image = var.image
      size  = 50
      type  = "pd-standard"
    }
  }

  network_interface {
    access_config {
      network_tier = "PREMIUM"
    }

    subnetwork = "projects/alvaro-demo-elastic-000001/regions/${var.region}/subnetworks/default"
  }  

  attached_disk {
    source = google_compute_disk.warm_disk[count.index].self_link
  }
  attached_disk {
    source = google_compute_disk.warm_logs_disks[count.index].self_link
  }
  metadata_startup_script = templatefile("${path.module}/config_and_install.tftpl", {
    es_keystore_pass = var.es_keystore_pass
    es_ca_pass = var.es_ca_pass
    instances_cert_pass = var.instances_cert_pass
  })
}

# kibana Logs disks creation
resource "google_compute_disk" "kibana_logs_disks" {
  count = var.kibana_count
  name  = "kibana-logs-disk-${count.index}"
  type  = "pd-standard"
  size  = 30
  zone = var.zone[1]
}

# kibana node disk creation
resource "google_compute_disk" "kibana_disk" {
  count = var.kibana_count
  name = "kibana-disk"
  type = "pd-standard"
  size = 100
  zone = var.zone[1]
}

# VM instances creation - kibana nodes
resource "google_compute_instance" "kibana_node" {
  service_account {
    email  = "terraform-service-account@alvaro-demo-elastic-000001.iam.gserviceaccount.com"
    scopes = ["https://www.googleapis.com/auth/devstorage.read_write"]
  }
  count = var.kibana_count
  name = "kibana-node"
  machine_type = var.kibana_machine_type
  tags = var.kibana_tags
  allow_stopping_for_update = true
  zone = var.zone[1] 

  boot_disk {
    initialize_params {
      image = var.image
      size  = 50
      type  = "pd-standard"
    }
  }

  network_interface {
    access_config {
      network_tier = "PREMIUM"
    }

    subnetwork = "projects/alvaro-demo-elastic-000001/regions/${var.region}/subnetworks/default"
  }

  attached_disk {
    source = google_compute_disk.kibana_disk[count.index].self_link
  }
  attached_disk {
    source = google_compute_disk.kibana_logs_disks[count.index].self_link
  }
  metadata_startup_script = templatefile("${path.module}/config_and_install.tftpl", {
    es_keystore_pass = var.es_keystore_pass
    es_ca_pass = var.es_ca_pass
    instances_cert_pass = var.instances_cert_pass
  })
}

data "google_compute_network" "default_network" {
  name = var.network_name
}

# Private DNS Zone
resource "google_dns_managed_zone" "private_zone" {
  name        = var.dns_name
  dns_name    = var.dns_domain
  description = "Elasticsearch internal private DNS"
  visibility  = "private"
  private_visibility_config {
    networks {
      network_url = data.google_compute_network.default_network.self_link
    }
  }
}

# Master DNS Records
resource "google_dns_record_set" "master_node_dns" {
  count        = var.master_count
  name         = "master-node-${count.index}.${var.dns_domain}"
  type         = "A"
  ttl          = 300
  managed_zone = google_dns_managed_zone.private_zone.name
  rrdatas      = [google_compute_instance.master_nodes[count.index].network_interface.0.network_ip]
}

# hot DNS Records
resource "google_dns_record_set" "hot_node_dns" {
  count        = var.hot_count
  name         = "hot-node-${count.index}.${var.dns_domain}"
  type         = "A"
  ttl          = 300
  managed_zone = google_dns_managed_zone.private_zone.name
  rrdatas      = [google_compute_instance.hot_nodes[count.index].network_interface.0.network_ip]
}

# Warm DNS Records
resource "google_dns_record_set" "warm_node_dns" {
  count        = var.warm_count
  name         = "warm-node-${count.index}.${var.dns_domain}"
  type         = "A"
  ttl          = 300
  managed_zone = google_dns_managed_zone.private_zone.name
  rrdatas      = [google_compute_instance.warm_node[count.index].network_interface.0.network_ip]
}

# kibana DNS Records
resource "google_dns_record_set" "kibana_node_dns" {
  count        = var.kibana_count
  name         = "kibana-node-${count.index}.${var.dns_domain}"
  type         = "A"
  ttl          = 300
  managed_zone = google_dns_managed_zone.private_zone.name
  rrdatas      = [google_compute_instance.kibana_node[count.index].network_interface.0.network_ip]
}
