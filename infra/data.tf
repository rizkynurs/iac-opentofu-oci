data "oci_identity_availability_domains" "ads" {
  compartment_id = var.tenancy_ocid
}

# Prefer Canonical Ubuntu 24.04 Minimal aarch64
data "oci_core_images" "ubuntu2404_minimal" {
  compartment_id           = var.compartment_ocid
  operating_system         = "Canonical Ubuntu"
  operating_system_version = "24.04"
  shape                    = var.shape
  sort_by                  = "TIMECREATED"
  sort_order               = "DESC"
  # More permissive name pattern; avoid requiring 'Gen2' and tolerate naming drift
  filter {
    name   = "display_name"
    values = ["^Canonical-Ubuntu-24.04.*Minimal.*(aarch64|Arm).*$"]
    regex  = true
  }
}

# Fallback: Standard Canonical Ubuntu 24.04 aarch64 (non-minimal)
data "oci_core_images" "ubuntu2404" {
  compartment_id           = var.compartment_ocid
  operating_system         = "Canonical Ubuntu"
  operating_system_version = "24.04"
  shape                    = var.shape
  sort_by                  = "TIMECREATED"
  sort_order               = "DESC"
  filter {
    name   = "display_name"
    values = ["^Canonical-Ubuntu-24.04-.*(aarch64|Arm).*$"]
    regex  = true
  }
}

locals {
  ubuntu_image_id = (
    length(data.oci_core_images.ubuntu2404_minimal.images) > 0 ? data.oci_core_images.ubuntu2404_minimal.images[0].id :
    (length(data.oci_core_images.ubuntu2404.images) > 0 ? data.oci_core_images.ubuntu2404.images[0].id : null)
  )
}
