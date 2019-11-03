
resource "oci_core_instance" "client_node" {
  count               = "${var.client_node["node_count"]}"
  availability_domain = "${lookup(data.oci_identity_availability_domains.ADs.availability_domains[( (count.index <  (var.client_node["node_count"] / 2)) ? local.site1 : local.site2)],"name")}"

  fault_domain        = "FAULT-DOMAIN-${(count.index%3)+1}"
  compartment_id      = "${var.compartment_ocid}"
  display_name        = "${var.client_node["hostname_prefix"]}${format("%01d", count.index+1)}"
  hostname_label      = "${var.client_node["hostname_prefix"]}${format("%01d", count.index+1)}"
  shape               = "${var.client_node["shape"]}"
  subnet_id           = oci_core_subnet.privateb.*.id[0]

  source_details {
    source_type = "image"
    source_id = "${var.images[var.region]}"
  }

  launch_options {
    network_type = "VFIO"
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
        "clientNodeCount=\"${var.client_node["node_count"]}\"",
        "clientNodeHostnamePrefix=\"${var.client_node["hostname_prefix"]}\"",
        "gpfsMountPoint=\"${var.spectrum_scale["gpfs_mount_point"]}\"",
        "highAvailability=\"${var.spectrum_scale["high_availability"]}\"",
        "installerNode=\"${var.client_node["hostname_prefix"]}${var.installer_node}\"",
        "vcnFQDN=\"${local.vcn_fqdn}\"",
        "privateBSubnetsFQDN=\"${local.privateBSubnetsFQDN}\"",
        "companyName=\"${var.callhome["company_name"]}\"",
        "companyID=\"${var.callhome["company_id"]}\"",
        "countryCode=\"${var.callhome["country_code"]}\"",
        "emailaddress=\"${var.callhome["emailaddress"]}\"",
        file("${var.scripts_directory}/firewall.sh"),
        file("${var.scripts_directory}/set_env_variables.sh"),
        file("${var.scripts_directory}/update_resolv_conf.sh"),
        file("${var.scripts_directory}/configure_nic.sh"),
        file("${var.scripts_directory}/infra_tuning.sh"),
        file("${var.scripts_directory}/passwordless_ssh.sh"),
        file("${var.scripts_directory}/install_spectrum_scale.sh")
      )))}"
    }

  timeouts {
    create = "120m"
  }

}



/* bastion instances */
resource "oci_core_instance" "bastion" {
  count = "${var.bastion["node_count"]}"
  availability_domain = "${lookup(data.oci_identity_availability_domains.ADs.availability_domains[((count.index % 2 == 0) ? local.site1 : local.site2)],"name")}"
  fault_domain        = "FAULT-DOMAIN-${(count.index%3)+1}"
  compartment_id      = "${var.compartment_ocid}"
  display_name        = "${var.bastion["hostname_prefix"]}${format("%01d", count.index+1)}"
  shape               = "${var.bastion["shape"]}"
  hostname_label      = "${var.bastion["hostname_prefix"]}${format("%01d", count.index+1)}"

  create_vnic_details {
    subnet_id              = "${oci_core_subnet.public.*.id[0]}"
    skip_source_dest_check = true
  }

  metadata = {
    ssh_authorized_keys = "${var.ssh_public_key}"
  }

  source_details {
    source_type = "image"
    source_id   = "${var.images[var.region]}"
  }
}



/* Remote exec to deploy gpfs software/rpms on client nodes */
resource "null_resource" "deploy_gpfs_on_client_nodes" {
  depends_on = [
    oci_core_instance.client_node
  ]
  count = "${var.client_node["node_count"]}"
  triggers = {
    instance_ids = "oci_core_instance.client_node.*.id"
  }

  provisioner "file" {
    source      = "${var.scripts_directory}/"
    destination = "/tmp/"
    connection {
      agent               = false
      timeout             = "30m"
      host                = element(oci_core_instance.client_node.*.private_ip, count.index)
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
      host                = element(oci_core_instance.client_node.*.private_ip, count.index)
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




/* Remote exec to create gpfs cluster on installer node */
resource "null_resource" "create_gpfs_cluster" {
  depends_on = [
    oci_core_instance.client_node,
    null_resource.deploy_gpfs_on_client_nodes
  ]
  count = 1
  triggers = {
    instance_ids = "oci_core_instance.client_node.*.id"
  }

  provisioner "remote-exec" {
    connection {
      agent               = false
      timeout             = "30m"
      host                = element(oci_core_instance.client_node.*.private_ip, count.index)
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
      "sudo su -l -c 'set -x && /tmp/create_spectrum_scale_cluster.sh'",
    ]
  }
}




