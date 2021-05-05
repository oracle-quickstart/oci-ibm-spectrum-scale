

resource "oci_core_instance" "QuorumNode" {
  count               = local.derived_quorum_node_count
  availability_domain = "${lookup(data.oci_identity_availability_domains.ADs.availability_domains[var.AD - 1],"name")}"
  fault_domain        = "FAULT-DOMAIN-${(2)+1}"
  compartment_id      = "${var.compartment_ocid}"
  display_name        = "${var.QuorumNodeHostnamePrefix}${format("%01d", count.index+1)}"
  shape               = "${var.QuorumNodeShape}"

  create_vnic_details {
    subnet_id           = local.private_subnet_id
    hostname_label      = "${var.QuorumNodeHostnamePrefix}${format("%01d", count.index+1)}"
    assign_public_ip    = "false"
  }


  source_details {
    source_type = "image"
    source_id = "${var.InstanceImageOCID[var.region]}"
  }

  launch_options {
    network_type = (length(regexall("VM.Standard.E", var.QuorumNodeShape)) > 0 ? "PARAVIRTUALIZED" : "VFIO")
  }

  metadata = {
    ssh_authorized_keys = "${var.ssh_public_key}"
    user_data = "${base64encode(join("\n", list(
        "#!/usr/bin/env bash",
        "set -x",
        "version=\"${var.ibm_ss_version}\"",
        "downloadUrl=\"${var.software_download_url}\"",
        "sshPrivateKey=\"${var.ssh_private_key}\"",
        "sshPublicKey=\"${var.ssh_public_key}\"",
        "clientNodeCount=\"${var.ComputeNodeCount}\"",
        "clientNodeHostnamePrefix=\"${var.ComputeNodeHostnamePrefix}\"",
        "blockSize=\"${var.BlockSize}\"",
        "dataReplica=\"${var.DataReplica}\"",
        "metadataReplica=\"${var.metadataReplica}\"",
        "gpfsMountPoint=\"${var.GpfsMountPoint}\"",
        "fileSystemName=\"${var.fileSystemName}\"",
        "sharedDataDiskCount=\"${var.SharedData["Count"]}\"",
        "installerNode=\"${var.ComputeNodeHostnamePrefix}${var.installer_node}\"",
        "privateSubnetsFQDN=\"${local.private_subnet_domain_name}\"",
        "quorumNodeCount=\"${local.derived_quorum_node_count}\"",
        "quorumNodeHostnamePrefix=\"${var.QuorumNodeHostnamePrefix}\"",
        file("${var.scripts_directory}/boot.sh")
      )))}"
    }


  timeouts {
    create = "60m"
  }

}


resource "null_resource" "copy_nsddevices_to_quorum_node" {
    depends_on = [oci_core_instance.QuorumNode]
    count      = local.derived_quorum_node_count
    provisioner "file" {
      source = "../direct_attached_scripts/nsddevices"
      destination = "/tmp/nsddevices"
      connection {
        agent               = false
        timeout             = "30m"
        host                = "${element(oci_core_instance.QuorumNode.*.private_ip, count.index)}"
        user                = "${var.ssh_user}"
        private_key         = "${var.ssh_private_key}"
        bastion_host        = "${oci_core_instance.bastion.*.public_ip[0]}"
        bastion_port        = "22"
        bastion_user        = "${var.ssh_user}"
        bastion_private_key = "${var.ssh_private_key}"
      }
    }
}




resource "oci_core_volume" "QuorumNode_fsd_blockvolume" {
  count               = local.derived_quorum_node_count

  availability_domain = "${lookup(data.oci_identity_availability_domains.ADs.availability_domains[var.AD - 1],"name")}"
  compartment_id      = "${var.compartment_ocid}"
  display_name        = "quorum-fsd-desc-only-vol1"
  size_in_gbs         = "50"
}


resource "oci_core_volume_attachment" "QuorumNode_fsd_blockvolume_attach" {
  attachment_type = "iscsi"
  count           = local.derived_quorum_node_count * 1
    
  instance_id  = element(oci_core_instance.QuorumNode.*.id, count.index)
  volume_id    = element(oci_core_volume.QuorumNode_fsd_blockvolume.*.id, count.index)
  is_shareable = true
  device       = var.SharedDataVolumeAttachDeviceMapping[( count.index + var.SharedData["Count"] )]

  provisioner "remote-exec" {
    connection {
      agent               = false
      timeout             = "30m"
      host                = "${element(oci_core_instance.QuorumNode.*.private_ip, count.index )}"
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

resource "oci_core_volume_attachment" "ComputeNode_fsd_blockvolume_attach" {
  attachment_type = "iscsi"
  count           = var.ComputeNodeCount * local.derived_quorum_node_count
  
  instance_id  = element(oci_core_instance.ComputeNode.*.id, count.index)
  volume_id    = element(oci_core_volume.QuorumNode_fsd_blockvolume.*.id, 0)
  is_shareable = true
  device       = var.SharedDataVolumeAttachDeviceMapping[( 0 + var.SharedData["Count"] )]

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


#variable total_nsd_node_pools { default="1" }
#variable block_volumes_per_pool { default="4" }
#variable nsd_nodes_per_pool { default="2" }

locals {
  total_nsd_node_pools="1"
  block_volumes_per_pool=var.SharedData["Count"]
  nsd_nodes_per_pool=var.ComputeNodeCount
}


# Please do not change them. These are for multi-attach block volume Terraform logic.
variable total_nsd_node_pools_list {
  type = list(number)
  default = [0]
}
variable nsd_nodes_per_pool_list {
  type = list(number)
  default = [0,1,2,3,4,5,6,7]
}
variable block_volumes_per_pool_list {
  type = list(number)
  default = [0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31]
}



locals {
  test_multi_attach_command_list = flatten(
    [for a in var.total_nsd_node_pools_list :
       [
       [for b in var.nsd_nodes_per_pool_list :
         [
          [for c in var.block_volumes_per_pool_list :
             [
               "${((a*local.nsd_nodes_per_pool)+b)} ${((a*local.block_volumes_per_pool)+c)} ${(c)} "
             ] if c < local.block_volumes_per_pool
          ]
         ] if b < local.nsd_nodes_per_pool
       ]
       ] if a < local.total_nsd_node_pools
    ]
  )
}


resource "oci_core_volume_attachment" "ComputeNode_shared_data_blockvolume_attach" {
  attachment_type = "iscsi"
  count = length(local.test_multi_attach_command_list)

  instance_id = element(oci_core_instance.ComputeNode.*.id, element(split(" ", local.test_multi_attach_command_list[count.index]),0) ,)
  volume_id = element(oci_core_volume.SharedDataBlockVolume.*.id, ( element(split(" ", local.test_multi_attach_command_list[count.index]),1)  )   )
  is_shareable = true
  
  device       = var.SharedDataVolumeAttachDeviceMapping[( element(split(" ", local.test_multi_attach_command_list[count.index]),2)  )]


  provisioner "remote-exec" {
    connection {
      agent   = false
      timeout = "30m"
      host    = element(oci_core_instance.ComputeNode.*.private_ip, ( element(split(" ", local.test_multi_attach_command_list[count.index]),0) )   )

      user                = var.ssh_user
      private_key         = var.ssh_private_key
      bastion_host        = oci_core_instance.bastion[0].public_ip
      bastion_port        = "22"
      bastion_user        = var.ssh_user
      bastion_private_key = var.ssh_private_key

    }

    inline = [
      "sudo -s bash -c 'set -x && iscsiadm -m node -o new -T ${self.iqn} -p ${self.ipv4}:${self.port}'",
      "sudo -s bash -c 'set -x && iscsiadm -m node -o update -T ${self.iqn} -n node.startup -v automatic '",
      "sudo -s bash -c 'set -x && iscsiadm -m node -T ${self.iqn} -p ${self.ipv4}:${self.port} -l '",
      "delay=`shuf -i 5-30 -n 1` ; echo $delay ; sleep $delay ;"
    ]
  }
}


resource "oci_core_volume_attachment" "QuorumNode_shared_data_blockvolume_attach" {
  attachment_type = "iscsi"
  count = var.SharedData["Count"] * local.derived_quorum_node_count

  instance_id = element(oci_core_instance.QuorumNode.*.id, 0)
  volume_id = element(oci_core_volume.SharedDataBlockVolume.*.id, count.index)
  is_shareable = true
  device       = var.SharedDataVolumeAttachDeviceMapping[( count.index )]

  provisioner "remote-exec" {
    connection {
      agent   = false
      timeout = "30m"
      host    = element(oci_core_instance.QuorumNode.*.private_ip, (count.index))

      user                = var.ssh_user
      private_key         = var.ssh_private_key
      bastion_host        = oci_core_instance.bastion[0].public_ip
      bastion_port        = "22"
      bastion_user        = var.ssh_user
      bastion_private_key = var.ssh_private_key

    }

    inline = [
      "sudo -s bash -c 'set -x && iscsiadm -m node -o new -T ${self.iqn} -p ${self.ipv4}:${self.port}'",
      "sudo -s bash -c 'set -x && iscsiadm -m node -o update -T ${self.iqn} -n node.startup -v automatic '",
      "sudo -s bash -c 'set -x && iscsiadm -m node -T ${self.iqn} -p ${self.ipv4}:${self.port} -l '",
      "delay=`shuf -i 5-30 -n 1` ; echo $delay ; sleep $delay ;"
    ]
  }
}



resource "null_resource" "notify_compute_nodes_oci_cli_multi_attach_complete" {
    depends_on = [oci_core_volume_attachment.ComputeNode_shared_data_blockvolume_attach,
                  oci_core_volume_attachment.ComputeNode_fsd_blockvolume_attach,
                ]
    count      = "${var.ComputeNodeCount}"
    provisioner "remote-exec" {
      connection {
        agent               = false
        timeout             = "30m"
        host                = "${element(oci_core_instance.ComputeNode.*.private_ip, count.index)}"
        user                = "${var.ssh_user}"
        private_key         = "${var.ssh_private_key}"
        bastion_host        = "${oci_core_instance.bastion.*.public_ip[0]}"
        bastion_port        = "22"
        bastion_user        = "${var.ssh_user}"
        bastion_private_key = "${var.ssh_private_key}"
      }
      inline = [
        "set -x",
        "sudo touch /tmp/multi-attach.complete",
      ]
    }
}

resource "null_resource" "notify_quorum_node_oci_cli_multi_attach_complete" {
    depends_on = [
        oci_core_volume_attachment.QuorumNode_fsd_blockvolume_attach,
        oci_core_volume_attachment.QuorumNode_shared_data_blockvolume_attach,
    ]
    count      = local.derived_quorum_node_count
    provisioner "remote-exec" {
      connection {
        agent               = false
        timeout             = "30m"
        host                = "${element(oci_core_instance.QuorumNode.*.private_ip, count.index)}"
        user                = "${var.ssh_user}"
        private_key         = "${var.ssh_private_key}"
        bastion_host        = "${oci_core_instance.bastion.*.public_ip[0]}"
        bastion_port        = "22"
        bastion_user        = "${var.ssh_user}"
        bastion_private_key = "${var.ssh_private_key}"
      }
      inline = [
        "set -x",
        "sudo touch /tmp/multi-attach.complete",
      ]
    }
}



/* Remote exec to deploy gpfs software/rpms on quorum node */
resource "null_resource" "deploy_gpfs_on_quorum_nodes" {
  depends_on = [
    oci_core_instance.QuorumNode,
    oci_core_volume_attachment.QuorumNode_fsd_blockvolume_attach,
    oci_core_volume_attachment.QuorumNode_shared_data_blockvolume_attach,
    null_resource.notify_quorum_node_oci_cli_multi_attach_complete,
  ]
  count = local.derived_quorum_node_count
  triggers = {
    instance_ids = "oci_core_instance.QuorumNode.*.id"
  }

  provisioner "file" {
    source      = "${var.scripts_directory}/nodes-cloud-init-complete-status-check.sh"
    destination = "/tmp/nodes-cloud-init-complete-status-check.sh"
    connection {
      agent               = false
      timeout             = "30m"
      host                = element(oci_core_instance.QuorumNode.*.private_ip, count.index)
      user                = var.ssh_user
      private_key         = var.ssh_private_key
      bastion_host        = oci_core_instance.bastion[0].public_ip
      bastion_port        = "22"
      bastion_user        = var.ssh_user
      bastion_private_key = var.ssh_private_key
    }
  }

  provisioner "file" {
    source      = "${var.scripts_directory}/deploy_spectrum_scale.sh"
    destination = "/tmp/deploy_spectrum_scale.sh"
    connection {
      agent               = false
      timeout             = "30m"
      host                = element(oci_core_instance.QuorumNode.*.private_ip, count.index)
      user                = var.ssh_user
      private_key         = var.ssh_private_key
      bastion_host        = oci_core_instance.bastion[0].public_ip
      bastion_port        = "22"
      bastion_user        = var.ssh_user
      bastion_private_key = var.ssh_private_key
    }
  }

  provisioner "remote-exec" {
    connection {
      agent               = false
      timeout             = "30m"
      host                = element(oci_core_instance.QuorumNode.*.private_ip, count.index)
      user                = var.ssh_user
      private_key         = var.ssh_private_key
      bastion_host        = oci_core_instance.bastion[0].public_ip
      bastion_port        = "22"
      bastion_user        = var.ssh_user
      bastion_private_key = var.ssh_private_key
    }
    inline = [
      "set -x",
      "echo about to run /tmp/nodes-cloud-init-complete-status-check.sh",
      "sudo -s bash -c 'set -x && chmod 777 /tmp/*.sh'",
      "sudo -s bash -c 'set -x && /tmp/nodes-cloud-init-complete-status-check.sh'",
      "sudo -s bash -c 'set -x && /tmp/deploy_spectrum_scale.sh'",
    ]
  }
}
