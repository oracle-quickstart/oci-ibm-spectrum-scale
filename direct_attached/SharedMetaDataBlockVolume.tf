

resource "oci_core_volume" "SharedMetaDataBlockVolume" {
  count               = "${var.SharedMetaData["Count"]}"


  availability_domain = "${lookup(data.oci_identity_availability_domains.ADs.availability_domains[var.AD - 1],"name")}"
  compartment_id      = "${var.compartment_ocid}"
  display_name        = "SharedMetaData${count.index+1}"
  size_in_gbs         = "${var.SharedMetaData["Size"]}"
}



