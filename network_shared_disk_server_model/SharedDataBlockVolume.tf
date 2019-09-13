locals {
  shared_data_disk_count = (var.total_nsd_node_pools * var.block_volumes_per_pool)
}

resource "oci_core_volume" "shared_data_block_volume" {
  count               = "${var.total_nsd_node_pools * var.block_volumes_per_pool}"
  availability_domain = "${lookup(data.oci_identity_availability_domains.ADs.availability_domains[((count.index <  (local.shared_data_disk_count / 2)) ? local.site1 : local.site2)],"name")}"
  compartment_id      = "${var.compartment_ocid}"
  display_name        = "SharedData${count.index+1}"
  size_in_gbs         = "${var.nsd["size"]}"
}


