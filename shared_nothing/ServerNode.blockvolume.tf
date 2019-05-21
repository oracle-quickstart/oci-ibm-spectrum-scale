

resource "oci_core_volume" "ServerNode_blockvolume" {
  count               = "${var.ServerNodeCount * var.DiskPerNode}"

  availability_domain = "${lookup(data.oci_identity_availability_domains.ADs.availability_domains[var.AD - 1],"name")}"
  compartment_id      = "${var.compartment_ocid}"
  display_name        = "${var.ServerNodeHostnamePrefix}${(count.index%var.ServerNodeCount+1)}-vol${(count.index%var.DiskPerNode+1)}"
  size_in_gbs         = "${var.DiskSize}"
}


resource "oci_core_volume_attachment" "ServerNode_blockvolume_attach" {
  attachment_type = "iscsi"
  count           = "${var.ServerNodeCount * var.DiskPerNode}"
  compartment_id  = "${var.compartment_ocid}"
  instance_id     = "${element(oci_core_instance.ServerNode.*.id, count.index%var.ServerNodeCount)}"
  volume_id       = "${element(oci_core_volume.ServerNode_blockvolume.*.id, count.index)}"

  provisioner "remote-exec" {
    connection {
      agent               = false
      timeout             = "30m"
      host                = "${element(oci_core_instance.ServerNode.*.private_ip, count.index%var.ServerNodeCount )}"
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



