

resource "oci_core_volume" "SharedDataBlockVolume" {
  count               = "${var.SharedData["Count"] * var.ServerNodeCount}"

  availability_domain = "${lookup(data.oci_identity_availability_domains.ADs.availability_domains[var.AD - 1],"name")}"
  compartment_id      = "${var.compartment_ocid}"
  display_name        = "SharedData${count.index+1}"
  size_in_gbs         = "${var.SharedData["Size"]}"
}


