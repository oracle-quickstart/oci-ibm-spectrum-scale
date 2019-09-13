# Gets a list of Availability Domains
data "oci_identity_availability_domains" "ADs" {
  compartment_id = "${var.tenancy_ocid}"
}

/*
data "template_file" "mgmt_gui_boot_script" {
  template =  "${file("${var.scripts_directory}/mgmt_gui_boot.sh.tpl")}"
  vars = {
    version = var.spectrum_scale["version"]
  }
}
*/
