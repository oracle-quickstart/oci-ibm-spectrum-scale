resource "oci_core_instance" "GPFSMgmtGUINode" {
  count               = "${var.GPFSMgmtGUINodeCount}"
  availability_domain = "${lookup(data.oci_identity_availability_domains.ADs.availability_domains[var.AD - 1],"name")}"
  compartment_id      = "${var.compartment_ocid}"
  display_name        = "${var.GPFSMgmtGUINodeHostnamePrefix}${format("%01d", count.index+1)}"
  hostname_label      = "${var.GPFSMgmtGUINodeHostnamePrefix}${format("%01d", count.index+1)}"
  shape               = "${var.GPFSMgmtGUINodeShape}"
  subnet_id           = "${oci_core_subnet.privateb.*.id[var.AD - 1]}"

  source_details {
    source_type = "image"
    source_id = "${var.InstanceImageOCID[var.region]}"
    #boot_volume_size_in_gbs = "${var.DiskSize}"
  }

  metadata {
    ssh_authorized_keys = "${var.ssh_public_key}"
    user_data = "${base64encode(data.template_file.mgmt_gui_boot_script.rendered)}"
  }

  timeouts {
    create = "60m"
  }

}





