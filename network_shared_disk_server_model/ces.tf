resource "oci_core_instance" "ces_node" {
  count               = var.ces_node_count
  availability_domain = local.ad

  fault_domain        = "FAULT-DOMAIN-${(count.index%3)+1}"
  compartment_id      = var.compartment_ocid
  display_name        = "${var.ces_node_hostname_prefix}ptcl-${format("%01d", count.index+1)}"
  shape               = (local.dual_nics_ces_node ? var.ces_node_shape : var.ces_node_shape)

  create_vnic_details {
    subnet_id           = oci_core_subnet.protocol_subnet.*.id[0]
    hostname_label      = "${var.ces_node_hostname_prefix}ptcl-${format("%01d", count.index+1)}"
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


resource "null_resource" "deploy_ssh_keys_on_ces_nodes" {
  depends_on = [
    oci_core_instance.ces_node,
  ]
  count = var.ces_node_count
  triggers = {
    instance_ids = "oci_core_instance.ces_node.*.id"
  }

  provisioner "file" {
    content     = tls_private_key.ssh.private_key_pem
    destination = "/home/opc/.ssh/id_rsa"
    connection {
      agent               = false
      timeout             = "30m"
      host                = element(oci_core_instance.ces_node.*.private_ip, count.index)
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
      host                = element(oci_core_instance.ces_node.*.private_ip, count.index)
      user                = var.ssh_user
      private_key         = tls_private_key.ssh.private_key_pem
      bastion_host        = oci_core_instance.bastion[0].public_ip
      bastion_port        = "22"
      bastion_user        = var.ssh_user
      bastion_private_key = tls_private_key.ssh.private_key_pem
    }
  }

}


/* Remote exec to deploy gpfs software/rpms on ces nodes */
resource "null_resource" "deploy_gpfs_on_ces_nodes" {
  depends_on = [
    oci_core_instance.ces_node  ]
  count = var.ces_node_count
  triggers = {
    instance_ids = "oci_core_instance.ces_node.*.id"
  }

  provisioner "file" {
    source      = "${var.scripts_directory}/"
    destination = "/tmp/"
    connection {
      agent               = false
      timeout             = "30m"
      host                = element(oci_core_instance.ces_node.*.private_ip, count.index)
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
      host                = element(oci_core_instance.ces_node.*.private_ip, count.index)
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



/* Remote exec to configure ces service on ss-ces-1 node */
resource "null_resource" "configure_ces_service" {
  depends_on = [
    oci_core_instance.ces_node,
    null_resource.create_gpfs_cluster
  ]
  count = var.ces_node_count > 0 ? 1 : 0
  # 1
  triggers = {
    instance_ids = element(concat(oci_core_instance.ces_node.*.id, [""]), 0)
  }

  provisioner "remote-exec" {
    connection {
      agent               = false
      timeout             = "30m"
      host                = element(oci_core_instance.ces_node.*.private_ip, count.index)
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
      "sudo su -l -c 'set -x && /tmp/configure_ces.sh'",
    ]
  }
}
