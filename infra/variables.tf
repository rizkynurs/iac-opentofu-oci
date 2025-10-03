variable "tenancy_ocid" {
  type = string
}

variable "user_ocid" {
  type = string
}

variable "fingerprint" {
  type = string
}

variable "private_key_path" {
  type = string
}

variable "region" {
  type = string
}

variable "compartment_ocid" {
  type = string
}

variable "vcn_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

variable "subnet_cidr" {
  type    = string
  default = "10.0.1.0/24"
}

variable "shape" {
  type    = string
  default = "VM.Standard.A1.Flex"
}

variable "a1_ocpus" {
  type    = number
  default = 1
}

variable "a1_memory_gbs" {
  type    = number
  default = 6
}


variable "boot_volume_size_gb" {
  type    = number
  default = 50
}

variable "instance_display_name" {
  type    = string
  default = "simple-web-vm"
}

# your public key content
variable "ssh_authorized_key" {
  type = string
}

variable "grafana_admin_user" {
  type    = string
  default = "admin"
}

variable "grafana_admin_password" {
  type    = string
  default = "admin123"
}

# Optional tags
variable "freeform_tags" {
  type = map(string)
  default = {
    project = "simple-web-demo"
  }
}


variable "image_ocid" {
  description = "Optional explicit image OCID to use. If set, overrides auto-discovery."
  type        = string
  default     = ""
}
