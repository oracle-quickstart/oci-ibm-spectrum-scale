resource "oci_core_instance" "ServerNode" {
  count               = "${var.ServerNodeCount}"
  availability_domain = "${lookup(data.oci_identity_availability_domains.ADs.availability_domains[var.AD - 1],"name")}"
  compartment_id      = "${var.compartment_ocid}"
  display_name        = "${var.ServerNodeHostnamePrefix}${format("%01d", count.index+1)}"
  hostname_label      = "${var.ServerNodeHostnamePrefix}${format("%01d", count.index+1)}"
  shape               = "${var.ServerNodeShape}"
  subnet_id           = "${oci_core_subnet.private.*.id[var.AD - 1]}"

  source_details {
    source_type = "image"
    source_id = "${var.InstanceImageOCID[var.region]}"
    #boot_volume_size_in_gbs = "${var.DiskSize}"
  }

  metadata {
    ssh_authorized_keys = "${var.ssh_public_key}"
    user_data = "${base64encode(data.template_file.boot_script.rendered)}"
  }

  timeouts {
    create = "60m"
  }

}



resource "oci_core_instance" "ComputeNode" {
  count               = "${var.ComputeNodeCount}"
  availability_domain = "${lookup(data.oci_identity_availability_domains.ADs.availability_domains[var.AD - 1],"name")}"
  compartment_id      = "${var.compartment_ocid}"
  display_name        = "${var.ComputeNodeHostnamePrefix}${format("%01d", count.index+1)}"
  hostname_label      = "${var.ComputeNodeHostnamePrefix}${format("%01d", count.index+1)}"
  shape               = "${var.ComputeNodeShape}"
  subnet_id           = "${oci_core_subnet.privateb.*.id[var.AD - 1]}"

  source_details {
    source_type = "image"
    source_id = "${var.InstanceImageOCID[var.region]}"
    #boot_volume_size_in_gbs = "${var.boot_volume_size}"
  }

  metadata {
    ssh_authorized_keys = "${var.ssh_public_key}"
    user_data = "${base64encode(data.template_file.boot_script.rendered)}"
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
  hostname_label      = "bastion-${format("%01d", count.index+1)}"

  create_vnic_details {
    subnet_id              = "${oci_core_subnet.public.*.id[var.AD - 1]}"
    skip_source_dest_check = true
  }

  metadata {
    ssh_authorized_keys = "${var.ssh_public_key}"
  }


  source_details {
    source_type = "image"
    source_id   = "${var.InstanceImageOCID[var.region]}"
  }
}



/*
Resource to check if the user_data/cloud-init script was successfully completed.
*/

resource "null_resource" "deploy_ibm_ss" {
    depends_on = ["oci_core_instance.ServerNode" , "null_resource.notify_server_nodes_oci_cli_multi_attach_complete" ]
    count               = "1"
    triggers {
      instance_ids = "oci_core_instance.ServerNode.*.id[0]"
      # "${join(",", oci_core_instance.ServerNode.*.id[0])}"
    }
 /*
    provisioner "file" {
      source = "${var.ssh_private_key_path}"
      destination = "/home/${var.ssh_user}/.ssh/id_rsa"
      connection {
        agent               = false
        timeout             = "30m"
        host                = "${element(oci_core_instance.ServerNode.*.private_ip, count.index)}"
        user                = "${var.ssh_user}"
        private_key         = "${var.ssh_private_key}"
        bastion_host        = "${oci_core_instance.bastion.*.public_ip[0]}"
        bastion_port        = "22"
        bastion_user        = "${var.ssh_user}"
        bastion_private_key = "${var.ssh_private_key}"
      }
    }
 */
    provisioner "file" {
      source = "${var.scripts_directory}/nodes-cloud-init-complete-status-check.sh"
      destination = "/tmp/nodes-cloud-init-complete-status-check.sh"
      connection {
        agent               = false
        timeout             = "30m"
        host                = "${element(oci_core_instance.ServerNode.*.private_ip, count.index)}"
        user                = "${var.ssh_user}"
        private_key         = "${var.ssh_private_key}"
        bastion_host        = "${oci_core_instance.bastion.*.public_ip[0]}"
        bastion_port        = "22"
        bastion_user        = "${var.ssh_user}"
        bastion_private_key = "${var.ssh_private_key}"
      }
    }

    provisioner "file" {
      source = "${var.scripts_directory}/deploy_ibm_ss.sh"
      destination = "/tmp/deploy_ibm_ss.sh"
      connection {
        agent               = false
        timeout             = "30m"
        host                = "${element(oci_core_instance.ServerNode.*.private_ip, count.index)}"
        user                = "${var.ssh_user}"
        private_key         = "${var.ssh_private_key}"
        bastion_host        = "${oci_core_instance.bastion.*.public_ip[0]}"
        bastion_port        = "22"
        bastion_user        = "${var.ssh_user}"
        bastion_private_key = "${var.ssh_private_key}"
      }
    }
    
    
    provisioner "remote-exec" {
      connection {
        agent               = false
        timeout             = "30m"
        host                = "${element(oci_core_instance.ServerNode.*.private_ip, count.index)}"
        user                = "${var.ssh_user}"
        private_key         = "${var.ssh_private_key}"
        bastion_host        = "${oci_core_instance.bastion.*.public_ip[0]}"
        bastion_port        = "22"
        bastion_user        = "${var.ssh_user}"
        bastion_private_key = "${var.ssh_private_key}"
      }
      inline = [
        "set -x",
        "echo about to run /tmp/nodes-cloud-init-complete-status-check.sh",
        "sudo -s bash -c 'set -x && chmod 777 /tmp/*.sh'",        
        "sudo -s bash -c 'set -x && /tmp/nodes-cloud-init-complete-status-check.sh'",
        "sudo -s bash -c 'set -x && /tmp/deploy_ibm_ss.sh'",
      ]
    }
    
}




