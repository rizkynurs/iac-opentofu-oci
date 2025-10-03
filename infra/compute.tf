resource "oci_core_instance" "vm" {
  availability_domain = data.oci_identity_availability_domains.ads.availability_domains[0].name
  compartment_id      = var.compartment_ocid
  display_name        = var.instance_display_name
  shape               = var.shape

  shape_config {
    ocpus         = var.a1_ocpus
    memory_in_gbs = var.a1_memory_gbs
  }

  freeform_tags = var.freeform_tags

  create_vnic_details {
    subnet_id        = oci_core_subnet.public.id
    assign_public_ip = true
    nsg_ids          = [oci_core_network_security_group.nsg.id]
  }

  source_details {
    source_type             = "image"
    source_id               = var.image_ocid != "" ? var.image_ocid : local.ubuntu_image_id
    boot_volume_size_in_gbs = var.boot_volume_size_gb
  }

  metadata = {
    ssh_authorized_keys = var.ssh_authorized_key
    user_data = base64gzip(templatefile("${path.module}/cloudinit.yaml", {
      grafana_admin_user     = var.grafana_admin_user
      grafana_admin_password = var.grafana_admin_password
    }))
  }

  lifecycle {
    precondition {
      condition     = var.image_ocid != "" || local.ubuntu_image_id != null
      error_message = "No Canonical Ubuntu 24.04 (Minimal/Standard) aarch64 image found for shape ${var.shape} in this region/compartment. Set var.image_ocid explicitly or adjust filters."
    }
  }
}
