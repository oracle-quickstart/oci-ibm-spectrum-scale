

resource "oci_core_instance" "ComputeNode" {
  count               = "${var.ComputeNodeCount}"
  availability_domain = "${lookup(data.oci_identity_availability_domains.ADs.availability_domains[var.AD - 1],"name")}"
  compartment_id      = "${var.compartment_ocid}"
  display_name        = "${var.ComputeNodeHostnamePrefix}${format("%01d", count.index+1)}"
  shape               = "${var.ComputeNodeShape}"

  create_vnic_details {
    subnet_id           = local.private_subnet_id
    hostname_label      = "${var.ComputeNodeHostnamePrefix}${format("%01d", count.index+1)}"
    assign_public_ip    = "false"
  }


  source_details {
    source_type = "image"
    source_id = "${var.InstanceImageOCID[var.region]}"
  }

  launch_options {
    network_type = (length(regexall("VM.Standard.E", var.ComputeNodeShape)) > 0 ? "PARAVIRTUALIZED" : "VFIO")
  }

  metadata = {
    ssh_authorized_keys = "${var.ssh_public_key}"
    #user_data = "${base64encode(data.template_file.boot_script.rendered)}"
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
        file("${var.scripts_directory}/boot.sh")
      )))}"
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

  create_vnic_details {
    subnet_id           = local.bastion_subnet_id
    hostname_label      = "bastion-${format("%01d", count.index+1)}"
    skip_source_dest_check = true
  }

  metadata = {
    ssh_authorized_keys = "${var.ssh_public_key}"
  }


  source_details {
    source_type = "image"
    source_id   = "${var.InstanceImageOCID[var.region]}"
  }
}



/* Remote exec to deploy gpfs software/rpms on client nodes */
resource "null_resource" "deploy_gpfs_on_client_nodes" {
  depends_on = [
    oci_core_instance.ComputeNode,
    null_resource.notify_compute_nodes_oci_cli_multi_attach_complete,
  ]
  count = var.ComputeNodeCount
  triggers = {
    instance_ids = "oci_core_instance.ComputeNode.*.id"
  }

  provisioner "file" {
    source      = "${var.scripts_directory}/nodes-cloud-init-complete-status-check.sh"
    destination = "/tmp/nodes-cloud-init-complete-status-check.sh"
    connection {
      agent               = false
      timeout             = "30m"
      host                = element(oci_core_instance.ComputeNode.*.private_ip, count.index)
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
      host                = element(oci_core_instance.ComputeNode.*.private_ip, count.index)
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
      host                = element(oci_core_instance.ComputeNode.*.private_ip, count.index)
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
    oci_core_instance.ComputeNode,
    null_resource.notify_compute_nodes_oci_cli_multi_attach_complete,
    null_resource.deploy_gpfs_on_client_nodes,
  ]
  count = 1
  triggers = {
    instance_ids = "oci_core_instance.ComputeNode.*.id"
  }

  provisioner "file" {
    source      = "${var.scripts_directory}/create_spectrum_scale_cluster.sh"
    destination = "/tmp/create_spectrum_scale_cluster.sh"
    connection {
      agent               = false
      timeout             = "30m"
      host                = element(oci_core_instance.ComputeNode.*.private_ip, count.index)
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
      host                = element(oci_core_instance.ComputeNode.*.private_ip, count.index)
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
