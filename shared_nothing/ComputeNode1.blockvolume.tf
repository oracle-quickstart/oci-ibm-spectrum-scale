

resource "oci_core_volume" "ComputeNode1_blockvolume" {
  count               = "1"

  availability_domain = "${lookup(data.oci_identity_availability_domains.ADs.availability_domains[var.AD - 1],"name")}"
  compartment_id      = "${var.compartment_ocid}"
  display_name        = "${var.ComputeNodeHostnamePrefix}${(count.index+1)}-vol1"
  size_in_gbs         = "50"
}


resource "oci_core_volume_attachment" "ComputeNode_blockvolume_attach" {
  attachment_type = "iscsi"
  count           = "1"
  compartment_id  = "${var.compartment_ocid}"
  instance_id     = "${element(oci_core_instance.ComputeNode.*.id, count.index)}"
  volume_id       = "${element(oci_core_volume.ComputeNode1_blockvolume.*.id, count.index)}"

  provisioner "remote-exec" {
    connection {
      agent               = false
      timeout             = "30m"
      host                = "${element(oci_core_instance.ComputeNode.*.private_ip, count.index )}"
      user                = "${var.ssh_user}"
      private_key         = "${var.ssh_private_key}"
      bastion_host        = "${oci_core_instance.bastion.*.public_ip[0]}"
      bastion_port        = "22"
      bastion_user        = "${var.ssh_user}"
      bastion_private_key = "${var.ssh_private_key}"
    }

    inline = [
      "sudo -s bash -c 'set -x && iscsiadm -m node -o new -T ${self.iqn} -p ${self.ipv4}:${self.port}'",
      "sudo -s bash -c 'set -x && iscsiadm -m node -o update -T ${self.iqn} -n node.startup -v automatic '",
      "sudo -s bash -c 'set -x && iscsiadm -m node -T ${self.iqn} -p ${self.ipv4}:${self.port} -l '",
    ]
  }
}



