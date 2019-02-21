resource "oci_core_instance" "ibmss_1" {
  count               = "${var.ibmss_1_count}"
  availability_domain = "${lookup(data.oci_identity_availability_domains.ADs.availability_domains[var.AD - 1],"name")}"
  compartment_id      = "${var.compartment_ocid}"
  display_name        = "IBM SS Server 1" #${format("%01d", count.index+1)}
  hostname_label      = "IBM-SS-Server-1" #${format("%01d", count.index+1)}
  shape               = "${var.ibmss_1_server_shape}"
  subnet_id           = "${oci_core_subnet.public.*.id[var.AD - 1]}"

  source_details {
    source_type = "image"
    source_id = "${var.InstanceImageOCID[var.region]}"
    #boot_volume_size_in_gbs = "${var.boot_volume_size}"
  }

  metadata {
    ssh_authorized_keys = "${var.ssh_public_key}"
    user_data = "${base64encode(data.template_file.boot_script.rendered)}"
    #user_data =  "${base64encode(file(../scripts/lustre.sh))}"
    #user_data           = "${base64encode(file("../scripts/ibmss_1.sh"))}"
  }

  timeouts {
    create = "60m"
  }

}



resource "oci_core_instance" "ibmss_2" {
  count               = "${var.ibmss_2_count}"
  availability_domain = "${lookup(data.oci_identity_availability_domains.ADs.availability_domains[var.AD - 1],"name")}"
  compartment_id      = "${var.compartment_ocid}"
  display_name        = "IBM SS Server 2" # ${format("%01d", count.index+1)}
  hostname_label      = "IBM-SS-Server-2" #${format("%01d", count.index+1)}
  shape               = "${var.ibmss_2_server_shape}"
  subnet_id           = "${oci_core_subnet.public.*.id[var.AD - 1]}"

  source_details {
    source_type = "image"
    source_id = "${var.InstanceImageOCID[var.region]}"
    #boot_volume_size_in_gbs = "${var.boot_volume_size}"
  }

  metadata {
    ssh_authorized_keys = "${var.ssh_public_key}"
    user_data = "${base64encode(data.template_file.boot_script.rendered)}"
    #user_data =  "${base64encode(file(../scripts/lustre.sh))}"
    #user_data           = "${base64encode(file("../scripts/lustre.sh"))}"
  }

  timeouts {
    create = "60m"
  }

}


resource "oci_core_instance" "ibmss_3" {
  count               = "${var.ibmss_3_count}"
  availability_domain = "${lookup(data.oci_identity_availability_domains.ADs.availability_domains[var.AD - 1],"name")}"
  compartment_id      = "${var.compartment_ocid}"
  display_name        = "IBM SS Server 3" #${format("%01d", count.index+1)}
  hostname_label      = "IBM-SS-Server-3" #${format("%01d", count.index+1)}
  shape               = "${var.ibmss_3_shape}"
  subnet_id           = "${oci_core_subnet.public.*.id[var.AD - 1]}"

  source_details {
    source_type = "image"
    source_id = "${var.InstanceImageOCID[var.region]}"
    #boot_volume_size_in_gbs = "${var.boot_volume_size}"
  }

  metadata {
    ssh_authorized_keys = "${var.ssh_public_key}"
    user_data = "${base64encode(data.template_file.boot_script.rendered)}"
    #user_data =  "${base64encode(file(../scripts/lustre.sh))}"
    #user_data           = "${base64encode(file("../scripts/ibmss_3.sh"))}"
  }

  timeouts {
    create = "60m"
  }

}





/* bastion instances */

resource "oci_core_instance" "bastion" {
  count = "${var.bastion_server_count}"
  availability_domain = "${lookup(data.oci_identity_availability_domains.ADs.availability_domains[var.AD - 1],"name")}"
  compartment_id      = "${var.compartment_ocid}"
  display_name        = "bastion ${format("%01d", count.index+1)}"
  shape               = "${var.bastion_server_shape}"
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

resource "null_resource" "ibmss-1-update" {
    #depends_on = ["oci_core_instance.ibmss_1" , "oci_core_volume.ibmss_1_blockvolume", "oci_core_volume_attachment.mds_blockvolume_attach" ]
    count               = "${var.ibmss_1_count}"
    triggers {
      instance_ids = "${join(",", oci_core_instance.ibmss_1.*.id)}"
    }

    provisioner "file" {
      source = "${var.ssh_private_key_path}"
      destination = "/home/${var.ssh_user}/.ssh/id_rsa"
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
    }
    /*
    provisioner "file" {
      source = "../scripts/nodes-cloud-init-complete-status-check.sh"
      destination = "/tmp/nodes-cloud-init-complete-status-check.sh"
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
    }

    provisioner "file" {
      source = "../scripts/mds_setup.sh"
      destination = "/tmp/mds_setup.sh"
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
    }
    */
    /*
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
        "set -x",
        "echo about to run /tmp/nodes-cloud-init-complete-status-check.sh",
        "sudo -s bash -c 'set -x && chmod 777 /tmp/*.sh'",        
        "sudo -s bash -c 'set -x && /tmp/nodes-cloud-init-complete-status-check.sh'",
        "sudo -s bash -c 'set -x && /tmp/mds_setup.sh'",
      ]
    }
    */
}


/*
Resource to check if the user_data/cloud-init script was successfully completed.
*/

resource "null_resource" "ibmss-2--update" {
    #depends_on = ["oci_core_instance.ibmss_2" , "oci_core_volume.ibmss_2_blockvolume" , "oci_core_volume_attachment.blockvolume_attach" , "null_resource.lustre-mds-setup-after-kernel-update"]
    count               = "${var.ibmss_2_count}"
    triggers {
      instance_ids = "${join(",", oci_core_instance.ibmss_2.*.id)}"
    }

    provisioner "file" {
      source = "${var.ssh_private_key_path}"
      destination = "/home/${var.ssh_user}/.ssh/id_rsa"
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
    }
    /*
    provisioner "file" {
      source = "../scripts/nodes-cloud-init-complete-status-check.sh"
      destination = "/tmp/nodes-cloud-init-complete-status-check.sh"
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
    }

    provisioner "file" {
      source = "../scripts/oss_setup.sh"
      destination = "/tmp/oss_setup.sh"
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
    }


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
        "set -x",
        "echo about to run /tmp/nodes-cloud-init-complete-status-check.sh",
        "sudo -s bash -c 'set -x && chmod 777 /tmp/*.sh'",
        "sudo -s bash -c 'set -x && /tmp/nodes-cloud-init-complete-status-check.sh'",
        "sudo -s bash -c 'set -x && /tmp/oss_setup.sh'",
      ]
    }
    */
}


/*
Resource to check if the user_data/cloud-init script was successfully completed.
*/

resource "null_resource" "ibmss-3-update" {
    #depends_on = ["oci_core_instance.ibmss_3", "null_resource.lustre-oss-setup-after-kernel-update", "null_resource.lustre-mds-setup-after-kernel-update"  ]
    count               = "${var.ibmss_3_count}"
    triggers {
      instance_ids = "${join(",", oci_core_instance.ibmss_3.*.id)}"
    }

    provisioner "file" {
      source = "${var.ssh_private_key_path}"
      destination = "/home/${var.ssh_user}/.ssh/id_rsa"
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
    }
    /*
    provisioner "file" {
      source = "../scripts/nodes-cloud-init-complete-status-check.sh"
      destination = "/tmp/nodes-cloud-init-complete-status-check.sh"
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
    }

    provisioner "file" {
      source = "../scripts/client_setup.sh"
      destination = "/tmp/client_setup.sh"
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
    }


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
        "set -x",
        "echo about to run /tmp/nodes-cloud-init-complete-status-check.sh",
        "sudo -s bash -c 'set -x && chmod 777 /tmp/*.sh'",
        "sudo -s bash -c 'set -x && /tmp/nodes-cloud-init-complete-status-check.sh'",
        "sudo -s bash -c 'set -x && /tmp/client_setup.sh'",
      ]
    }
    */
}


resource "oci_core_instance" "ibmss_client" {
  count               = "${var.ibmss_client_count}"
  availability_domain = "${lookup(data.oci_identity_availability_domains.ADs.availability_domains[var.AD - 1],"name")}"
  compartment_id      = "${var.compartment_ocid}"
  display_name        = "IBM SS Client ${format("%01d", count.index+1)}"
  hostname_label      = "IBM-SS-Client-${format("%01d", count.index+1)}"
  shape               = "${var.ibmss_client_shape}"
  subnet_id           = "${oci_core_subnet.public.*.id[var.AD - 1]}"

  source_details {
    source_type = "image"
    source_id = "${var.InstanceImageOCID[var.region]}"
    #boot_volume_size_in_gbs = "${var.boot_volume_size}"
  }

  metadata {
    ssh_authorized_keys = "${var.ssh_public_key}"
    user_data = "${base64encode(data.template_file.boot_script.rendered)}"
    #user_data =  "${base64encode(file(../scripts/lustre.sh))}"
    #user_data           = "${base64encode(file("../scripts/ibmss_1.sh"))}"
  }

  timeouts {
    create = "60m"
  }

}


/*
Resource to check if the user_data/cloud-init script was successfully completed.
*/

resource "null_resource" "ibmss-client-update" {
    depends_on = ["oci_core_instance.ibmss_client" ]
    count               = "${var.ibmss_client_count}"
    triggers {
      instance_ids = "${join(",", oci_core_instance.ibmss_client.*.id)}"
    }

    provisioner "file" {
      source = "${var.ssh_private_key_path}"
      destination = "/home/${var.ssh_user}/.ssh/id_rsa"
      connection {
        agent               = false
        timeout             = "30m"
        host                = "${element(oci_core_instance.ibmss_client.*.private_ip, count.index)}"
        user                = "${var.ssh_user}"
        private_key         = "${var.ssh_private_key}"
        bastion_host        = "${oci_core_instance.bastion.*.public_ip[0]}"
        bastion_port        = "22"
        bastion_user        = "${var.ssh_user}"
        bastion_private_key = "${var.ssh_private_key}"
      }
    }
    
    provisioner "file" {
      source = "../scripts/nodes-cloud-init-complete-status-check.sh"
      destination = "/tmp/nodes-cloud-init-complete-status-check.sh"
      connection {
        agent               = false
        timeout             = "30m"
        host                = "${element(oci_core_instance.ibmss_client.*.private_ip, count.index)}"
        user                = "${var.ssh_user}"
        private_key         = "${var.ssh_private_key}"
        bastion_host        = "${oci_core_instance.bastion.*.public_ip[0]}"
        bastion_port        = "22"
        bastion_user        = "${var.ssh_user}"
        bastion_private_key = "${var.ssh_private_key}"
      }
    }

    provisioner "file" {
      source = "../scripts/ibm_ss_nodes_post_cloud_init_setup.sh"
      destination = "/tmp/ibm_ss_nodes_post_cloud_init_setup.sh"
      connection {
        agent               = false
        timeout             = "30m"
        host                = "${element(oci_core_instance.ibmss_client.*.private_ip, count.index)}"
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
        host                = "${element(oci_core_instance.ibmss_client.*.private_ip, count.index)}"
        user                = "${var.ssh_user}"
        private_key         = "${var.ssh_private_key}"
        bastion_host        = "${oci_core_instance.bastion.*.public_ip[0]}"
        bastion_port        = "22"
        bastion_user        = "${var.ssh_user}"
        bastion_private_key = "${var.ssh_private_key}"
      }
      inline = [
        "set -x",
        "chmod 600 /home/${var.ssh_user}/.ssh/id_rsa",
        "echo about to run /tmp/nodes-cloud-init-complete-status-check.sh",
        "sudo -s bash -c 'set -x && chmod 777 /tmp/*.sh'",
        "sudo -s bash -c 'set -x && /tmp/nodes-cloud-init-complete-status-check.sh'",
        "sudo -s bash -c 'set -x && /tmp/ibm_ss_nodes_post_cloud_init_setup.sh'",
      ]
    }
    
}

