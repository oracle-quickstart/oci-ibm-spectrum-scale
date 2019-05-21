
resource "oci_core_volume" "ibmss_1_blockvolume" {
  count               = "${var.ibmss_1_count}"
  #count               = "${var.compute_platform == "linux" ? var.compute_instance_count : 0}"
  #availability_domain = "${element(var.availability_domain, count.index)}"
  availability_domain = "${lookup(data.oci_identity_availability_domains.ADs.availability_domains[var.AD - 1],"name")}"
  compartment_id      = "${var.compartment_ocid}"
  display_name        = "ibm-ss-1-vol${count.index+1}"
  size_in_gbs         = "${var.data_volume_size}"
}

resource "oci_core_volume_attachment" "1_blockvolume_attach" {
  attachment_type = "iscsi"
  count           = "${var.ibmss_1_count}"
  #count           = "${var.compute_platform == "linux" ? var.compute_instance_count : 0}"
  compartment_id  = "${var.compartment_ocid}"
  instance_id     = "${element(oci_core_instance.ibmss_1.*.id, count.index)}"
  volume_id       = "${element(oci_core_volume.ibmss_1_blockvolume.*.id, count.index)}"

  provisioner "remote-exec" {
    connection {
      agent               = false
      timeout             = "30m"
      host                = "${element(oci_core_instance.ibmss_1.*.private_ip, count.index)}"
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
      #"sudo -s bash -c 'set -x && pvcreate -y /dev/sdb'",
      #"sudo -s bash -c 'mkfs.xfs -f /dev/sdb'",
    ]
  }
}

resource "oci_core_volume" "ibmss_2_blockvolume" {
  count               = "${var.ibmss_2_count}"
  #availability_domain = "${element(var.availability_domain, count.index)}"
  availability_domain = "${lookup(data.oci_identity_availability_domains.ADs.availability_domains[var.AD - 1],"name")}"
  compartment_id      = "${var.compartment_ocid}"
  display_name        = "ibm-ss-2-vol${count.index+1}"
  size_in_gbs         = "${var.data_volume_size}"
}

resource "oci_core_volume_attachment" "2_blockvolume_attach" {
  attachment_type = "iscsi"
  count           = "${var.ibmss_2_count}"
  compartment_id  = "${var.compartment_ocid}"
  instance_id     = "${element(oci_core_instance.ibmss_2.*.id, count.index)}"
  volume_id       = "${element(oci_core_volume.ibmss_2_blockvolume.*.id, count.index)}"

  provisioner "remote-exec" {
    connection {
      agent               = false
      timeout             = "30m"
      host                = "${element(oci_core_instance.ibmss_2.*.private_ip, count.index)}"
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
      #"sudo -s bash -c 'set -x && pvcreate -y /dev/sdb'",
      #"sudo -s bash -c 'mkfs.xfs -f /dev/sdb'",
    ]
  }
}


resource "oci_core_volume" "ibmss_3_blockvolume" {
  count               = "${var.ibmss_3_count}"
  #availability_domain = "${element(var.availability_domain, count.index)}"
  availability_domain = "${lookup(data.oci_identity_availability_domains.ADs.availability_domains[var.AD - 1],"name")}"
  compartment_id      = "${var.compartment_ocid}"
  display_name        = "ibm-ss-3-vol${count.index+1}"
  size_in_gbs         = "${var.data_volume_size}"
}

resource "oci_core_volume_attachment" "3_blockvolume_attach" {
  attachment_type = "iscsi"
  count           = "${var.ibmss_3_count}"
  compartment_id  = "${var.compartment_ocid}"
  instance_id     = "${element(oci_core_instance.ibmss_3.*.id, count.index)}"
  volume_id       = "${element(oci_core_volume.ibmss_3_blockvolume.*.id, count.index)}"

  provisioner "remote-exec" {
    connection {
      agent               = false
      timeout             = "30m"
      host                = "${element(oci_core_instance.ibmss_3.*.private_ip, count.index)}"
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
      #"sudo -s bash -c 'set -x && pvcreate -y /dev/sdb'",
      #"sudo -s bash -c 'mkfs.xfs -f /dev/sdb'",
    ]
  }
}

