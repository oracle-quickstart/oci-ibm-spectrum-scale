
resource "oci_core_instance" "mgmt_gui_node" {
  count               = var.mgmt_gui_node["node_count"]
  availability_domain = lookup(data.oci_identity_availability_domains.ADs.availability_domains[( (count.index <  (var.mgmt_gui_node["node_count"] / 2)) ? local.site1 : local.site2)],"name")

  fault_domain        = "FAULT-DOMAIN-${(count.index%3)+1}"
  compartment_id      = var.compartment_ocid
  display_name        = "${var.mgmt_gui_node["hostname_prefix"]}${format("%01d", count.index+1)}"
  hostname_label      = "${var.mgmt_gui_node["hostname_prefix"]}${format("%01d", count.index+1)}"
  shape               = var.mgmt_gui_node["shape"]
#  subnet_id           = element(concat(oci_core_subnet.privateb.*.id, [""]), 0)
####  subnet_id           = local.dual_nics ? element(concat(oci_core_subnet.privateb.*.id, [""]), 0) : element(concat(oci_core_subnet.private.*.id, [""]), 0)
subnet_id           = element(concat(oci_core_subnet.privateb.*.id, [""]), 0)


  source_details {
    source_type = "image"
    source_id = var.images[var.region]
  }

  metadata = {
    ssh_authorized_keys = var.ssh_public_key
    user_data = "${base64encode(join("\n", list(
        "#!/usr/bin/env bash",
        "set -x",
        "version=\"${var.spectrum_scale["version"]}\"",
        "downloadUrl=\"${var.spectrum_scale["download_url"]}\"",
        "sshPrivateKey=\"${var.ssh_private_key}\"",
        "sshPublicKey=\"${var.ssh_public_key}\"",
        "totalNsdNodePools=\"${var.total_nsd_node_pools}\"",
        "nsdNodesPerPool=\"${var.nsd_nodes_per_pool}\"",
        "nsdNodeCount=\"${(var.total_nsd_node_pools * var.nsd_nodes_per_pool)}\"",
        "nsdNodeHostnamePrefix=\"${var.nsd_node["hostname_prefix"]}\"",
        "clientNodeCount=\"${var.client_node["node_count"]}\"",
        "clientNodeHostnamePrefix=\"${var.client_node["hostname_prefix"]}\"",
        "blockSize=\"${var.spectrum_scale["block_size"]}\"",
        "dataReplica=\"${var.spectrum_scale["data_replica"]}\"",
        "metadataReplica=\"${var.spectrum_scale["metadata_replica"]}\"",
        "gpfsMountPoint=\"${var.spectrum_scale["gpfs_mount_point"]}\"",
        "highAvailability=\"${var.spectrum_scale["high_availability"]}\"",
        "sharedDataDiskCount=\"${(var.total_nsd_node_pools * var.block_volumes_per_pool)}\"",
        "blockVolumesPerPool=\"${var.block_volumes_per_pool}\"",
        "installerNode=\"${var.nsd_node["hostname_prefix"]}${var.installer_node}\"",
        "vcnFQDN=\"${local.vcn_fqdn}\"",
        "privateSubnetsFQDN=\"${local.privateSubnetsFQDN}\"",
        "privateBSubnetsFQDN=\"${local.privateBSubnetsFQDN}\"",
        "companyName=\"${var.callhome["company_name"]}\"",
        "companyID=\"${var.callhome["company_id"]}\"",
        "countryCode=\"${var.callhome["country_code"]}\"",
        "emailaddress=\"${var.callhome["emailaddress"]}\"",
        "cesNodeCount=\"${var.ces_node["node_count"]}\"",
        "cesNodeHostnamePrefix=\"${var.ces_node["hostname_prefix"]}\"",
        "mgmtGuiNodeCount=\"${var.mgmt_gui_node["node_count"]}\"",
        "mgmtGuiNodeHostnamePrefix=\"${var.mgmt_gui_node["hostname_prefix"]}\"",
        "privateProtocolSubnetFQDN=\"${local.private_protocol_subnet_fqdn}\"",
        file("${var.scripts_directory}/firewall.sh"),
        file("${var.scripts_directory}/set_env_variables.sh"),
        file("${var.scripts_directory}/update_resolv_conf.sh"),
        file("${var.scripts_directory}/configure_nic.sh"),
        file("${var.scripts_directory}/block_volume_discovery.sh"),
        file("${var.scripts_directory}/infra_tuning.sh"),
        file("${var.scripts_directory}/passwordless_ssh.sh"),
        file("${var.scripts_directory}/install_spectrum_scale.sh")
#        file("${var.scripts_directory}/mgmt_gui_install.sh")
      )))}"
    }

  timeouts {
    create = "120m"
  }

}



/* Remote exec to deploy gpfs software/rpms on mgmt_gui nodes */
resource "null_resource" "deploy_gpfs_on_mgmt_gui_nodes" {
  depends_on = [
    oci_core_instance.mgmt_gui_node,
    null_resource.notify_server_nodes_oci_cli_multi_attach_complete,
  ]
  count = var.mgmt_gui_node["node_count"]
  triggers = {
    instance_ids = "oci_core_instance.mgmt_gui_node.*.id"
  }

  provisioner "file" {
    source      = "${var.scripts_directory}/"
    destination = "/tmp/"
    connection {
      agent               = false
      timeout             = "30m"
      host                = element(oci_core_instance.mgmt_gui_node.*.private_ip, count.index)
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
      host                = element(oci_core_instance.mgmt_gui_node.*.private_ip, count.index)
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




/* Remote exec to configure mgmt_gui service on mgmt_gui node 1 */
resource "null_resource" "configure_mgmt_gui_service" {
  depends_on = [
    oci_core_instance.mgmt_gui_node,
    null_resource.create_gpfs_cluster,
    null_resource.configure_ces_service
  ]
  count = var.mgmt_gui_node["node_count"] > 0 ? 1 : 0
  # 1
  triggers = {
    instance_ids = "oci_core_instance.mgmt_gui_node.*.id"
  }

  provisioner "remote-exec" {
    connection {
      agent               = false
      timeout             = "30m"
      host                = element(oci_core_instance.mgmt_gui_node.*.private_ip, count.index)
      user                = var.ssh_user
      private_key         = var.ssh_private_key
      bastion_host        = oci_core_instance.bastion[0].public_ip
      bastion_port        = "22"
      bastion_user        = var.ssh_user
      bastion_private_key = var.ssh_private_key
    }
    inline = [
      "set -x",
      "sudo -s bash -c 'set -x && chmod 777 /tmp/*.sh'",
      "sudo su -l -c 'set -x && /tmp/configure_mgmt_gui.sh'",
    ]
  }
}
