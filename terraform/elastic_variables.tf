variable "credentials" {
  description = "google credentials"
  type        = string
}

variable "project_name" {
  description = "Project name"
  type        = string
}

variable "zone" {
  description = "Zones"
  type        = list(string)
}

variable "image" {
  description = "Image"
  type        = string
}

variable "master_count" {
  description = "Number of master machines"
  type        = number
}

variable "hot_count" {
  description = "Number of hot machines"
  type        = number
}

variable "warm_count" {
  description = "Number of warm machines"
  type        = number
}

variable "kibana_count" {
  description = "Number of kibana machines"
  type        = number
}

variable "master_machine_type" {
  description = "Master machine type"
  type        = string
}

variable "hot_machine_type" {
  description = "Hot machine type"
  type        = string
}

variable "warm_machine_type" {
  description = "Warm machine type"
  type        = string
}

variable "kibana_machine_type" {
  description = "Kibana machine type"
  type        = string
}

variable "elastic_tags" {
  description = "Tags for elastic machines"
  type        = list(string)
}

variable "kibana_tags" {
  description = "Tags for kibana machines"
  type        = list(string)
}
