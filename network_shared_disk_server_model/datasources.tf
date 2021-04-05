# Gets a list of Availability Domains
data "oci_identity_availability_domains" "ADs" {
  compartment_id = var.tenancy_ocid
}



data "oci_core_vcn" "vcn" {
  vcn_id = var.use_existing_vcn ? var.vcn_id : oci_core_vcn.vcn[0].id
}

data "oci_core_subnet" "storage_subnet" {
  subnet_id = var.use_existing_vcn ? var.storage_subnet_id : local.storage_subnet_id
}

data "oci_core_subnet" "fs_subnet" {
  subnet_id = var.use_existing_vcn ? var.fs_subnet_id : local.fs_subnet_id
}

data "oci_core_subnet" "protocol_subnet" {
  subnet_id = var.use_existing_vcn ? var.protocol_subnet_id : local.protocol_subnet_id
}


resource "tls_private_key" "ssh" {
  algorithm = "RSA"
  rsa_bits  = "4096"
}
