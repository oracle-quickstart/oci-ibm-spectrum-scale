
/*
  Locally install the OCI CLI Limited Availability version which is required for Block Volume Multi-Attach feature
*/
resource "null_resource" "install_oci_cli_preview" {
   count               = "1"
   provisioner "local-exec" {
     command = "set -x; oci os bucket list --compartment-id ${var.compartment_ocid}; "
   }
}


/*
  Copy nsddevices file which is required to override default GPFS behavior to lookup NSD disk
*/
resource "null_resource" "copy_nsddevices_to_all_server_nodes" {
    depends_on = [oci_core_instance.nsd_node]
    count      = var.total_nsd_node_pools * var.nsd_nodes_per_pool
    provisioner "file" {
      source = "${var.scripts_directory}/nsddevices"
      destination = "/tmp/nsddevices"
      connection {
        agent               = false
        timeout             = "30m"
        host                = element(oci_core_instance.nsd_node.*.private_ip, count.index)
        user                = var.ssh_user
        private_key         = var.ssh_private_key
        bastion_host        = oci_core_instance.bastion.*.public_ip[0]
        bastion_port        = "22"
        bastion_user        = var.ssh_user
        bastion_private_key = var.ssh_private_key
      }
    }  
}

/*
  Logic to build OCI CLI commands to do multi-attach of BVol to compute instances
*/
locals {
  multi_attach_command_list = flatten(
    [for a in var.total_nsd_node_pools_list :
       [
       [for b in var.nsd_nodes_per_pool_list :
         [
          [for c in var.block_volumes_per_pool_list :
             [
               "oci compute volume-attachment attach --type iscsi --is-shareable true  --instance-id  ${oci_core_instance.nsd_node[((a*var.nsd_nodes_per_pool)+b)].id}  --volume-id ${oci_core_volume.shared_data_block_volume[((a*var.block_volumes_per_pool)+c)].id} --device ${var.volume_attach_device_mapping[(c)]}  --config-file ~/.oci/config "
             ] if c < var.block_volumes_per_pool
          ]
         ] if b < var.nsd_nodes_per_pool
       ]
       ] if a < var.total_nsd_node_pools
    ]
  )
}

/*
  Logic to run the OCI CLI commands to do multi-attach of BVol to compute instances
*/
resource "null_resource" "multi_attach_shared_data_bv_to_nsd_nodes" {
  depends_on = [
    oci_core_instance.nsd_node,
    oci_core_volume.shared_data_block_volume,
    null_resource.install_oci_cli_preview ,
    null_resource.copy_nsddevices_to_all_server_nodes
  ]
  count = length(local.multi_attach_command_list)

  /*
    length(local.multi_attach_command_list)
  */
  # 60-200
  provisioner "local-exec" {
    command = "delay=`shuf -i 5-30 -n 1` ; echo $delay ; sleep $delay ; ${local.multi_attach_command_list[count.index]} ; "
  }

}


/*
  Notify NSD server nodes that multi-attach is complete, so NSD server nodes can continue with their rest of the instance setup logic in cloud-init.
*/
resource "null_resource" "notify_server_nodes_oci_cli_multi_attach_complete" {
  depends_on = [ null_resource.multi_attach_shared_data_bv_to_nsd_nodes,
                    null_resource.copy_nsddevices_to_all_server_nodes]
  count      = var.total_nsd_node_pools * var.nsd_nodes_per_pool
  provisioner "remote-exec" {
    connection {
        agent               = false
        timeout             = "30m"
        host                = element(oci_core_instance.nsd_node.*.private_ip, count.index)
        user                = var.ssh_user
        private_key         = var.ssh_private_key
        bastion_host        = oci_core_instance.bastion.*.public_ip[0]
        bastion_port        = "22"
        bastion_user        = var.ssh_user
        bastion_private_key = var.ssh_private_key
    }
    inline = [
      "set -x",
      "sudo touch /tmp/multi-attach.complete",
    ]
  }
}



