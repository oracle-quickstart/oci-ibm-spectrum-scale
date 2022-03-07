


resource "null_resource" "copy_nsddevices_to_all_compute_nodes" {
    depends_on = [oci_core_instance.ComputeNode]
    count      = var.ComputeNodeCount
    provisioner "file" {
      source = "../direct_attached_scripts/nsddevices"
      destination = "/tmp/nsddevices"
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
    }      
}








/*
*
All commented code below - ignore them
*
*/



/*
*
*
resource "null_resource" "install_oci_cli_preview" {
   count               = "1"
   provisioner "local-exec" {
     command = "set -x; oci os bucket list --compartment-id ${var.compartment_ocid};"


   }
}
*/


/*
resource "null_resource" "multi_attach_shared_data_bv_to_server_nodes" {
    depends_on = ["oci_core_instance.ServerNode" , "oci_core_instance.ComputeNode", "oci_core_volume.SharedDataBlockVolume", "null_resource.install_oci_cli_preview" ]
    count               = "${var.ServerNodeCount * var.SharedData["Count"]}"

   provisioner "local-exec" {
     command = "oci compute volume-attachment attach --type iscsi --is-shareable true  --instance-id ${oci_core_instance.ServerNode.*.id[count.index%var.ServerNodeCount]}  --volume-id ${oci_core_volume.SharedDataBlockVolume.*.id[floor(count.index/var.ServerNodeCount)]} --device ${var.SharedDataVolumeAttachDeviceMapping[floor(count.index/var.ServerNodeCount)]};sleep 61s; "
   }
    
}
*/

/*
*
*
resource "null_resource" "multi_attach_shared_data_bv_to_compute_nodes" {
    depends_on = [oci_core_instance.ComputeNode, oci_core_volume.SharedDataBlockVolume, null_resource.install_oci_cli_preview ]
    count               = "${var.ComputeNodeCount * var.SharedData["Count"]}"

   provisioner "local-exec" {
     command = "sleep 45s;oci compute volume-attachment attach --type iscsi --is-shareable true  --instance-id ${oci_core_instance.ComputeNode.*.id[count.index%var.ComputeNodeCount]}  --volume-id ${oci_core_volume.SharedDataBlockVolume.*.id[floor(count.index/var.ComputeNodeCount)]} --device ${var.SharedDataVolumeAttachDeviceMapping[floor(count.index/var.ComputeNodeCount)]} ; "
   }

}
*/

/*
resource "null_resource" "multi_attach_shared_metadata_bv_to_server_nodes" {
    depends_on = ["oci_core_instance.ServerNode" , "oci_core_instance.ComputeNode", "oci_core_volume.SharedMetaDataBlockVolume", "null_resource.install_oci_cli_preview" ]
    count               = "${var.ServerNodeCount * var.SharedMetaData["Count"]}"

   provisioner "local-exec" {
     command = "sleep 90s; oci compute volume-attachment attach --type iscsi --is-shareable true  --instance-id ${oci_core_instance.ServerNode.*.id[count.index%var.ServerNodeCount]}  --volume-id ${oci_core_volume.SharedMetaDataBlockVolume.*.id[floor(count.index/var.ServerNodeCount)]}  --device ${var.SharedMetaDataVolumeAttachDeviceMapping[floor(count.index/var.ServerNodeCount)]};"
   }

}


resource "null_resource" "multi_attach_shared_metadata_bv_to_compute_nodes" {
    depends_on = ["oci_core_instance.ServerNode" , "oci_core_instance.ComputeNode", "oci_core_volume.SharedMetaDataBlockVolume", "null_resource.install_oci_cli_preview" ]
    count               = "${var.ComputeNodeCount * var.SharedMetaData["Count"]}"
}
*/

/*
*
*
resource "null_resource" "notify_server_nodes_oci_cli_multi_attach_complete" {
    depends_on = ["null_resource.multi_attach_shared_metadata_bv_to_compute_nodes" , "null_resource.multi_attach_shared_metadata_bv_to_server_nodes", null_resource.multi_attach_shared_data_bv_to_compute_nodes, "null_resource.multi_attach_shared_data_bv_to_server_nodes" ]
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
*/




