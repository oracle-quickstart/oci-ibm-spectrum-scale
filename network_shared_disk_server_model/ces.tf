resource "oci_core_instance" "ces_node" {
  count               = "${var.ces_node["node_count"]}"
  availability_domain = "${lookup(data.oci_identity_availability_domains.ADs.availability_domains[( (count.index <  (var.ces_node["node_count"] / 2)) ? local.site1 : local.site2)],"name")}"

  compartment_id      = "${var.compartment_ocid}"
  display_name        = "${var.ces_node["hostname_prefix"]}${format("%01d", count.index+1)}"
  hostname_label      = "${var.ces_node["hostname_prefix"]}${format("%01d", count.index+1)}"
  shape               = "${var.ces_node["shape"]}"
  subnet_id           = (local.dual_nics ? oci_core_subnet.privateprotocol.*.id[0] : oci_core_subnet.privateb.*.id[0])

  source_details {
    source_type = "image"
    source_id = "${var.images[var.region]}"
  }

  metadata = {
    ssh_authorized_keys = "${var.ssh_public_key}"
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
        "privateSubnetsFQDN=\"${oci_core_virtual_network.gpfs.dns_label}.oraclevcn.com ${oci_core_subnet.private.*.dns_label[0]}.${oci_core_virtual_network.gpfs.dns_label}.oraclevcn.com\"",
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
        file("${var.scripts_directory}/protocol_install.sh")
      )))}"
    }

  timeouts {
    create = "120m"
  }

}

