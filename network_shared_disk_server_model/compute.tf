locals {
  nsd_node_count = (var.total_nsd_node_pools * var.nsd_nodes_per_pool)
}


resource "oci_core_instance" "nsd_node" {
  depends_on = [
    oci_core_instance.bastion,
  ]
  count               = local.nsd_node_count
  availability_domain = local.ad
  fault_domain        = "FAULT-DOMAIN-${(count.index%3)+1}"
  compartment_id      = var.compartment_ocid
  display_name        = (local.dual_vnic ? "${var.nsd_node_hostname_prefix}nic0-${format("%01d", count.index+1)}" : "${var.nsd_node_hostname_prefix}${format("%01d", count.index+1)}")
  shape               = var.nsd_node_shape

  create_vnic_details {
    subnet_id           = local.storage_subnet_id
    hostname_label      = (local.dual_vnic ? "${var.nsd_node_hostname_prefix}nic0-${format("%01d", count.index+1)}" : "${var.nsd_node_hostname_prefix}${format("%01d", count.index+1)}")
    assign_public_ip    = "false"
  }


  source_details {
    source_type = "image"
    source_id = var.images[var.region]
  }

  metadata = {
    ssh_authorized_keys = tls_private_key.ssh.public_key_openssh
#    ssh_authorized_keys = "${var.ssh_public_key}\n${tls_private_key.ssh.public_key_openssh}"
    user_data = base64encode(join("\n", list(
        "#!/usr/bin/env bash",
        "set -x",
        "version=\"${var.spectrum_scale_version}\"",
        "downloadUrl=\"${var.spectrum_scale_download_url}\"",
        "totalNsdNodePools=\"${var.total_nsd_node_pools}\"",
        "nsdNodesPerPool=\"${var.nsd_nodes_per_pool}\"",
        "nsdNodeCount=\"${(var.total_nsd_node_pools * var.nsd_nodes_per_pool)}\"",
        "nsdNodeHostnamePrefix=\"${var.nsd_node_hostname_prefix}\"",
        "clientNodeCount=\"${var.client_node_count}\"",
        "clientNodeHostnamePrefix=\"${var.client_node_hostname_prefix}\"",
        "blockSize=\"${var.spectrum_scale_block_size}\"",
        "dataReplica=\"${var.spectrum_scale_data_replica}\"",
        "metadataReplica=\"${var.spectrum_scale_metadata_replica}\"",
        "gpfsMountPoint=\"${var.spectrum_scale_gpfs_mount_point}\"",
        "sharedDataDiskCount=\"${(var.total_nsd_node_pools * var.block_volumes_per_pool)}\"",
        "blockVolumesPerPool=\"${var.block_volumes_per_pool}\"",
        "installerNode=\"${var.nsd_node_hostname_prefix}${var.installer_node}\"",
        "vcnFQDN=\"${local.vcn_domain_name}\"",
        "privateSubnetsFQDN=\"${local.storage_subnet_domain_name}\"",
        "privateBSubnetsFQDN=\"${local.filesystem_subnet_domain_name}\"",
        "cesNodeCount=\"${var.ces_node_count}\"",
        "cesNodeHostnamePrefix=\"${var.ces_node_hostname_prefix}\"",
        "mgmtGuiNodeCount=\"${var.mgmt_gui_node_count}\"",
        "mgmtGuiNodeHostnamePrefix=\"${var.mgmt_gui_node_hostname_prefix}\"",
        "privateProtocolSubnetFQDN=\"${local.protocol_subnet_domain_name}\"",
        file("${var.scripts_directory}/firewall.sh"),
        file("${var.scripts_directory}/set_env_variables.sh"),
        file("${var.scripts_directory}/update_resolv_conf.sh"),
        file("${var.scripts_directory}/configure_nic.sh"),
        file("${var.scripts_directory}/block_volume_discovery.sh"),
        file("${var.scripts_directory}/infra_tuning.sh"),
        file("${var.scripts_directory}/passwordless_ssh.sh"),
        file("${var.scripts_directory}/install_spectrum_scale.sh")
      )))
    }

  timeouts {
    create = "120m"
  }


}


resource "null_resource" "deploy_ssh_keys_on_nsd_server_nodes" {
  depends_on = [
    oci_core_instance.nsd_node,
  ]
  count = var.total_nsd_node_pools * var.nsd_nodes_per_pool
  triggers = {
    instance_ids = "oci_core_instance.nsd_node.*.id"
  }

  provisioner "file" {
    content     = tls_private_key.ssh.private_key_pem
    destination = "/home/opc/.ssh/id_rsa"
    connection {
      agent               = false
      timeout             = "30m"
      host                = element(oci_core_instance.nsd_node.*.private_ip, count.index)
      user                = var.ssh_user
      private_key         = tls_private_key.ssh.private_key_pem
      bastion_host        = oci_core_instance.bastion[0].public_ip
      bastion_port        = "22"
      bastion_user        = var.ssh_user
      bastion_private_key = tls_private_key.ssh.private_key_pem
    }
  }

  provisioner "file" {
    content     = tls_private_key.ssh.public_key_openssh
    destination = "/home/opc/.ssh/id_rsa.pub"
    connection {
      agent               = false
      timeout             = "30m"
      host                = element(oci_core_instance.nsd_node.*.private_ip, count.index)
      user                = var.ssh_user
      private_key         = tls_private_key.ssh.private_key_pem
      bastion_host        = oci_core_instance.bastion[0].public_ip
      bastion_port        = "22"
      bastion_user        = var.ssh_user
      bastion_private_key = tls_private_key.ssh.private_key_pem
    }
  }

}


resource "oci_core_instance" "client_node" {
  count               = var.client_node_count
  availability_domain = local.ad
  #lookup(data.oci_identity_availability_domains.ADs.availability_domains[( (count.index <  (var.client_node["node_count"] / 2)) ? local.site1 : local.site2)],"name")

  fault_domain        = "FAULT-DOMAIN-${(count.index%3)+1}"
  compartment_id      = var.compartment_ocid
  display_name        = "${var.client_node_hostname_prefix}${format("%01d", count.index+1)}"
  shape               = var.client_node_shape

  create_vnic_details {
    subnet_id           = local.client_subnet_id
    hostname_label      = "${var.client_node_hostname_prefix}${format("%01d", count.index+1)}"
    assign_public_ip    = "false"
  }


  source_details {
    source_type = "image"
    source_id = var.images[var.region]
  }

  metadata = {
    ssh_authorized_keys = tls_private_key.ssh.public_key_openssh
#    ssh_authorized_keys = "${var.ssh_public_key}\n${tls_private_key.ssh.public_key_openssh}"
    user_data = base64encode(join("\n", list(
        "#!/usr/bin/env bash",
        "set -x",
        "version=\"${var.spectrum_scale_version}\"",
        "downloadUrl=\"${var.spectrum_scale_download_url}\"",
        "totalNsdNodePools=\"${var.total_nsd_node_pools}\"",
        "nsdNodesPerPool=\"${var.nsd_nodes_per_pool}\"",
        "nsdNodeCount=\"${(var.total_nsd_node_pools * var.nsd_nodes_per_pool)}\"",
        "nsdNodeHostnamePrefix=\"${var.nsd_node_hostname_prefix}\"",
        "clientNodeCount=\"${var.client_node_count}\"",
        "clientNodeHostnamePrefix=\"${var.client_node_hostname_prefix}\"",
        "blockSize=\"${var.spectrum_scale_block_size}\"",
        "dataReplica=\"${var.spectrum_scale_data_replica}\"",
        "metadataReplica=\"${var.spectrum_scale_metadata_replica}\"",
        "gpfsMountPoint=\"${var.spectrum_scale_gpfs_mount_point}\"",
        "sharedDataDiskCount=\"${(var.total_nsd_node_pools * var.block_volumes_per_pool)}\"",
        "blockVolumesPerPool=\"${var.block_volumes_per_pool}\"",
        "installerNode=\"${var.nsd_node_hostname_prefix}${var.installer_node}\"",
        "vcnFQDN=\"${local.vcn_domain_name}\"",
        "privateSubnetsFQDN=\"${local.storage_subnet_domain_name}\"",
        "privateBSubnetsFQDN=\"${local.filesystem_subnet_domain_name}\"",
        "cesNodeCount=\"${var.ces_node_count}\"",
        "cesNodeHostnamePrefix=\"${var.ces_node_hostname_prefix}\"",
        "mgmtGuiNodeCount=\"${var.mgmt_gui_node_count}\"",
        "mgmtGuiNodeHostnamePrefix=\"${var.mgmt_gui_node_hostname_prefix}\"",
        "privateProtocolSubnetFQDN=\"${local.protocol_subnet_domain_name}\"",
        file("${var.scripts_directory}/firewall.sh"),
        file("${var.scripts_directory}/set_env_variables.sh"),
        file("${var.scripts_directory}/update_resolv_conf.sh"),
        file("${var.scripts_directory}/configure_nic.sh"),
        file("${var.scripts_directory}/block_volume_discovery.sh"),
        file("${var.scripts_directory}/infra_tuning.sh"),
        file("${var.scripts_directory}/passwordless_ssh.sh"),
        file("${var.scripts_directory}/install_spectrum_scale.sh")
      )))
    }

  timeouts {
    create = "120m"
  }

}


resource "null_resource" "deploy_ssh_keys_on_nsd_client_nodes" {
  depends_on = [
    oci_core_instance.client_node,
  ]
  count = var.client_node_count
  triggers = {
    instance_ids = "oci_core_instance.client_node.*.id"
  }

  provisioner "file" {
    content     = tls_private_key.ssh.private_key_pem
    destination = "/home/opc/.ssh/id_rsa"
    connection {
      agent               = false
      timeout             = "30m"
      host                = element(oci_core_instance.client_node.*.private_ip, count.index)
      user                = var.ssh_user
      private_key         = tls_private_key.ssh.private_key_pem
      bastion_host        = oci_core_instance.bastion[0].public_ip
      bastion_port        = "22"
      bastion_user        = var.ssh_user
      bastion_private_key = tls_private_key.ssh.private_key_pem
    }
  }

  provisioner "file" {
    content     = tls_private_key.ssh.public_key_openssh
    destination = "/home/opc/.ssh/id_rsa.pub"
    connection {
      agent               = false
      timeout             = "30m"
      host                = element(oci_core_instance.client_node.*.private_ip, count.index)
      user                = var.ssh_user
      private_key         = tls_private_key.ssh.private_key_pem
      bastion_host        = oci_core_instance.bastion[0].public_ip
      bastion_port        = "22"
      bastion_user        = var.ssh_user
      bastion_private_key = tls_private_key.ssh.private_key_pem
    }
  }

}


/* bastion instances */
resource "oci_core_instance" "bastion" {
  count = var.bastion_node_count
  availability_domain = local.ad
  fault_domain        = "FAULT-DOMAIN-${(count.index%3)+1}"
  compartment_id      = var.compartment_ocid
  display_name        = "${var.bastion_hostname_prefix}${format("%01d", count.index+1)}"
  shape               = var.bastion_shape

  create_vnic_details {
    subnet_id              = local.bastion_subnet_id
    skip_source_dest_check = true
    hostname_label      = "${var.bastion_hostname_prefix}${format("%01d", count.index+1)}"
  }

  metadata = {
    ssh_authorized_keys = "${var.ssh_public_key}\n${tls_private_key.ssh.public_key_openssh}"
  }

  source_details {
    source_type = "image"
    source_id   = var.images[var.region]
  }
  
  provisioner "file" {
    content     = tls_private_key.ssh.private_key_pem
    destination = "/home/opc/.ssh/cluster.key"
    connection {
      host        = oci_core_instance.bastion[0].public_ip
      type        = "ssh"
      user        = "opc"
      private_key = tls_private_key.ssh.private_key_pem
    }
  }

  provisioner "file" {
    content     = tls_private_key.ssh.private_key_pem
    destination = "/home/opc/.ssh/id_rsa"
    connection {
      host        = oci_core_instance.bastion[0].public_ip
      type        = "ssh"
      user        = "opc"
      private_key = tls_private_key.ssh.private_key_pem
    }
  }

  provisioner "remote-exec" {
    connection {
      host        = oci_core_instance.bastion[0].public_ip
      type        = "ssh"
      user        = "opc"
      private_key = tls_private_key.ssh.private_key_pem
    }
    inline = [
      "chmod 600 /home/opc/.ssh/id_rsa*",
      "chmod 600 /home/opc/.ssh/cluster.key",

    ]
  }
  
}



/* Remote exec to deploy gpfs software/rpms on client nodes */
resource "null_resource" "deploy_gpfs_on_client_nodes" {
  depends_on = [
    oci_core_instance.client_node,
    null_resource.notify_server_nodes_oci_cli_multi_attach_complete,
  ]
  count = var.client_node_count
  triggers = {
    instance_ids = "oci_core_instance.client_node.*.id"
  }
  /*
  provisioner "local-exec" {
    command = "echo \"wait until reboot completes\"; sleep 120s;"
  }
  */
  provisioner "file" {
    source      = "${var.scripts_directory}/nodes-cloud-init-complete-status-check.sh"
    destination = "/tmp/nodes-cloud-init-complete-status-check.sh"
    connection {
      agent               = false
      timeout             = "30m"
      host                = element(oci_core_instance.client_node.*.private_ip, count.index)
      user                = var.ssh_user
      private_key         = tls_private_key.ssh.private_key_pem
      bastion_host        = oci_core_instance.bastion[0].public_ip
      bastion_port        = "22"
      bastion_user        = var.ssh_user
      bastion_private_key = tls_private_key.ssh.private_key_pem
    }
  }

  provisioner "file" {
    source      = "${var.scripts_directory}/deploy_spectrum_scale.sh"
    destination = "/tmp/deploy_spectrum_scale.sh"
    connection {
      agent               = false
      timeout             = "30m"
      host                = element(oci_core_instance.client_node.*.private_ip, count.index)
      user                = var.ssh_user
      private_key         = tls_private_key.ssh.private_key_pem
      bastion_host        = oci_core_instance.bastion[0].public_ip
      bastion_port        = "22"
      bastion_user        = var.ssh_user
      bastion_private_key = tls_private_key.ssh.private_key_pem
    }
  }

  provisioner "remote-exec" {
    connection {
      agent               = false
      timeout             = "30m"
      host                = element(oci_core_instance.client_node.*.private_ip, count.index)
      user                = var.ssh_user
      private_key         = tls_private_key.ssh.private_key_pem
      bastion_host        = oci_core_instance.bastion[0].public_ip
      bastion_port        = "22"
      bastion_user        = var.ssh_user
      bastion_private_key = tls_private_key.ssh.private_key_pem
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


/* Remote exec to deploy gpfs software/rpms on nsd server nodes */
resource "null_resource" "deploy_gpfs_on_nsd_server_nodes" {
  depends_on = [
    oci_core_instance.nsd_node,
    null_resource.notify_server_nodes_oci_cli_multi_attach_complete,
  ]
  count = var.total_nsd_node_pools * var.nsd_nodes_per_pool
  triggers = {
    instance_ids = "oci_core_instance.nsd_node.*.id"
  }
  /*
  provisioner "local-exec" {
    command = "echo \"wait until reboot completes\"; sleep 300s;"
  }
  */

  provisioner "file" {
    source      = "${var.scripts_directory}/"
    destination = "/tmp/"
    connection {
      agent               = false
      timeout             = "30m"
      host                = element(oci_core_instance.nsd_node.*.private_ip, count.index)
      user                = var.ssh_user
      private_key         = tls_private_key.ssh.private_key_pem
      bastion_host        = oci_core_instance.bastion[0].public_ip
      bastion_port        = "22"
      bastion_user        = var.ssh_user
      bastion_private_key = tls_private_key.ssh.private_key_pem
    }
  }

  provisioner "remote-exec" {
    connection {
      agent               = false
      timeout             = "30m"
      host                = element(oci_core_instance.nsd_node.*.private_ip, count.index)
      user                = var.ssh_user
      private_key         = tls_private_key.ssh.private_key_pem
      bastion_host        = oci_core_instance.bastion[0].public_ip
      bastion_port        = "22"
      bastion_user        = var.ssh_user
      bastion_private_key = tls_private_key.ssh.private_key_pem
    }
    inline = [
      "set -x",
      "echo about to run /tmp/nodes-cloud-init-complete-status-check.sh",
      "sudo -s bash -c 'set -x && chmod 777 /tmp/*.sh'",
      "sudo -s bash -c 'set -x && /tmp/nodes-cloud-init-complete-status-check.sh'",
      "sudo su -l -c 'set -x && /tmp/deploy_spectrum_scale.sh'",
    ]
  }
}


/* Remote exec to create gpfs cluster on installer node */
resource "null_resource" "create_gpfs_cluster" {
  depends_on = [
    oci_core_instance.nsd_node,
    null_resource.notify_server_nodes_oci_cli_multi_attach_complete,
    null_resource.deploy_gpfs_on_nsd_server_nodes,
    null_resource.deploy_gpfs_on_client_nodes,
    null_resource.deploy_gpfs_on_ces_nodes,
    null_resource.deploy_gpfs_on_mgmt_gui_nodes
  ]
  count = 1
  triggers = {
    instance_ids = "oci_core_instance.nsd_node.*.id"
  }

  provisioner "remote-exec" {
    connection {
      agent               = false
      timeout             = "30m"
      host                = element(oci_core_instance.nsd_node.*.private_ip, count.index)
      user                = var.ssh_user
      private_key         = tls_private_key.ssh.private_key_pem
      bastion_host        = oci_core_instance.bastion[0].public_ip
      bastion_port        = "22"
      bastion_user        = var.ssh_user
      bastion_private_key = tls_private_key.ssh.private_key_pem
    }
    inline = [
      "set -x",
      "sudo -s bash -c 'set -x && chmod 777 /tmp/*.sh'",
      "sudo su -l -c 'set -x && /tmp/create_spectrum_scale_cluster.sh'",
    ]
  }
}




