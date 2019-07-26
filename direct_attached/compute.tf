resource "oci_core_instance" "ServerNode" {
  count               = "${var.ServerNodeCount}"
  availability_domain = "${lookup(data.oci_identity_availability_domains.ADs.availability_domains[var.AD - 1],"name")}"
  compartment_id      = "${var.compartment_ocid}"
  display_name        = "${var.ServerNodeHostnamePrefix}${format("%01d", count.index+1)}"
  hostname_label      = "${var.ServerNodeHostnamePrefix}${format("%01d", count.index+1)}"
  shape               = "${var.ServerNodeShape}"
  subnet_id           = "${oci_core_subnet.private.*.id[var.AD - 1]}"

  source_details {
    source_type = "image"
    source_id = "${var.InstanceImageOCID[var.region]}"
  }

  metadata {
    ssh_authorized_keys = "${var.ssh_public_key}"
    user_data = "${base64encode(data.template_file.boot_script.rendered)}"
  }

  timeouts {
    create = "60m"
  }

}



resource "oci_core_instance" "ComputeNode" {
  count               = "${var.ComputeNodeCount}"
  availability_domain = "${lookup(data.oci_identity_availability_domains.ADs.availability_domains[var.AD - 1],"name")}"
  compartment_id      = "${var.compartment_ocid}"
  display_name        = "${var.ComputeNodeHostnamePrefix}${format("%01d", count.index+1)}"
  hostname_label      = "${var.ComputeNodeHostnamePrefix}${format("%01d", count.index+1)}"
  shape               = "${var.ComputeNodeShape}"
  subnet_id           = "${oci_core_subnet.private.*.id[var.AD - 1]}"

  source_details {
    source_type = "image"
    source_id = "${var.InstanceImageOCID[var.region]}"
  }

  metadata {
    ssh_authorized_keys = "${var.ssh_public_key}"
    user_data = "${base64encode(data.template_file.boot_script.rendered)}"
  }

  timeouts {
    create = "60m"
  }

}



/* bastion instances */

resource "oci_core_instance" "bastion" {
  count = "${var.BastionNodeCount}"
  availability_domain = "${lookup(data.oci_identity_availability_domains.ADs.availability_domains[var.AD - 1],"name")}"
  compartment_id      = "${var.compartment_ocid}"
  display_name        = "bastion ${format("%01d", count.index+1)}"
  shape               = "${var.BastionNodeShape}"
  hostname_label      = "bastion-${format("%01d", count.index+1)}"

  create_vnic_details {
    subnet_id              = "${oci_core_subnet.public.*.id[var.AD - 1]}"
    skip_source_dest_check = true
  }

  metadata {
    ssh_authorized_keys = "${var.ssh_public_key}"
  }


  source_details {
    source_type = "image"
    source_id   = "${var.InstanceImageOCID[var.region]}"
  }
}







