resource "oci_core_vcn" "vcn" {
  compartment_id = var.compartment_ocid
  cidr_block     = var.vcn_cidr
  display_name   = "vcn-simple-web"
  freeform_tags  = var.freeform_tags
}

resource "oci_core_internet_gateway" "igw" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.vcn.id
  display_name   = "igw-simple-web"
  ## is_enabled     = true
}

resource "oci_core_security_list" "simple_ingress_egress" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.vcn.id
  display_name   = "sl-simple-web"

  # INGRESS: SSH 22
  ingress_security_rules {
    protocol    = "6" # TCP
    source      = "0.0.0.0/0"
    source_type = "CIDR_BLOCK"
    tcp_options {
      min = 22
      max = 22
    }
  }

  # INGRESS: HTTP 80
  ingress_security_rules {
    protocol    = "6"
    source      = "0.0.0.0/0"
    source_type = "CIDR_BLOCK"
    tcp_options {
      min = 80
      max = 80
    }
  }

  # EGRESS: allow all
  egress_security_rules {
    destination = "0.0.0.0/0"
    protocol    = "all"
  }
}

resource "oci_core_route_table" "rt" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.vcn.id
  display_name   = "rt-simple-web"
  route_rules {
    network_entity_id = oci_core_internet_gateway.igw.id
    destination       = "0.0.0.0/0"
    destination_type  = "CIDR_BLOCK"
  }
}

resource "oci_core_subnet" "public" {
  compartment_id             = var.compartment_ocid
  vcn_id                     = oci_core_vcn.vcn.id
  display_name               = "subnet-simple-web"
  cidr_block                 = var.subnet_cidr
  route_table_id             = oci_core_route_table.rt.id
  security_list_ids          = [oci_core_security_list.simple_ingress_egress.id]
  prohibit_public_ip_on_vnic = false
  freeform_tags              = var.freeform_tags
}

resource "oci_core_network_security_group" "nsg" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.vcn.id
  display_name   = "nsg-simple-web"
}

resource "oci_core_network_security_group_security_rule" "allow_ssh" {
  network_security_group_id = oci_core_network_security_group.nsg.id
  direction                 = "INGRESS"
  protocol                  = "6" # TCP

  tcp_options {
    destination_port_range {
      min = 22
      max = 22
    }
  }

  source      = "0.0.0.0/0"
  source_type = "CIDR_BLOCK"
}

resource "oci_core_network_security_group_security_rule" "allow_http" {
  network_security_group_id = oci_core_network_security_group.nsg.id
  direction                 = "INGRESS"
  protocol                  = "6" # TCP

  tcp_options {
    destination_port_range {
      min = 80
      max = 80
    }
  }

  source      = "0.0.0.0/0"
  source_type = "CIDR_BLOCK"
}
