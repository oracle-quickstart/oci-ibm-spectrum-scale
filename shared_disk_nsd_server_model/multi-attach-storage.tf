


resource "null_resource" "copy_nsddevices_to_all_server_nodes" {
    depends_on = ["oci_core_instance.ServerNode"]
    count      = "${var.ServerNodeCount}"
    provisioner "file" {
      source = "${var.scripts_directory}/nsddevices"
      destination = "/tmp/nsddevices"
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
}



resource "null_resource" "install_oci_cli_preview" {
   count               = "1"
   provisioner "local-exec" {
     command = "set -x; rm -rf ~/oci-cli-installer; mkdir -p ~/oci-cli-installer; cd ~/oci-cli-installer; wget -q ${var.oci_cli_download_url} ; file_path=${var.oci_cli_download_url} ; unzip oci-cli-full-install-2.4.40+preview.1.1330.zip  -d ./ ;./install.sh --accept-all-defaults;  oci os bucket list --compartment-id ${var.compartment_ocid}; mkdir -p ~/.oci ; cd ~/.oci ; echo \"[DEFAULT]\nuser=${var.user_ocid}\nfingerprint=${var.fingerprint}\nkey_file=${var.private_key_path}\ntenancy=${var.tenancy_ocid}\nregion=${var.region}\n\" > ~/.oci/config; "
   }
}



resource "null_resource" "multi_attach_shared_data_bv_to_server_nodes" {
    depends_on = ["oci_core_instance.ServerNode" , "oci_core_volume.SharedDataBlockVolume", "null_resource.install_oci_cli_preview" ]
    count               = "${var.ServerNodeCount * var.SharedData["Count"] * var.ServerNodeCount}"
/*
    triggers {
      instance_ids = "oci_core_instance.ServerNode.*.id[0]"
      # "${join(",", oci_core_instance.ServerNode.*.id[0])}"
      }
*/

   provisioner "local-exec" {
     command = "oci compute volume-attachment attach --type iscsi --is-shareable true  --instance-id ${oci_core_instance.ServerNode.*.id[count.index%var.ServerNodeCount]}  --volume-id ${oci_core_volume.SharedDataBlockVolume.*.id[floor(count.index/var.ServerNodeCount)]} --device ${var.SharedDataVolumeAttachDeviceMapping[floor(count.index/var.ServerNodeCount)]}   --config-file ~/.oci/config ;sleep 61s; "
   }
    
}






resource "null_resource" "notify_server_nodes_oci_cli_multi_attach_complete" {
    depends_on = [ "null_resource.multi_attach_shared_data_bv_to_server_nodes" ]
    count      = "${var.ServerNodeCount}"
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
        "sudo touch /tmp/multi-attach.complete",
      ]
    }  
}



