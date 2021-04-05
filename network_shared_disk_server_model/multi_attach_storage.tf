


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
        private_key         = tls_private_key.ssh.private_key_pem
        bastion_host        = oci_core_instance.bastion.*.public_ip[0]
        bastion_port        = "22"
        bastion_user        = var.ssh_user
        bastion_private_key = tls_private_key.ssh.private_key_pem
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

locals {
  test_multi_attach_command_list = flatten(
    [for a in var.total_nsd_node_pools_list :
       [
       [for b in var.nsd_nodes_per_pool_list :
         [
          [for c in var.block_volumes_per_pool_list :
             [
               "${((a*var.nsd_nodes_per_pool)+b)} ${((a*var.block_volumes_per_pool)+c)} ${(c)} "
             ] if c < var.block_volumes_per_pool
          ]
         ] if b < var.nsd_nodes_per_pool
       ]
       ] if a < var.total_nsd_node_pools
    ]
  )
}



/*
resource "null_resource" "test_multi_attach_shared_data_bv_to_nsd_nodes" {
  depends_on = [
    oci_core_instance.nsd_node,
    oci_core_volume.shared_data_block_volume,
    null_resource.copy_nsddevices_to_all_server_nodes
  ]
  count = length(local.test_multi_attach_command_list)

  # 60-200
  provisioner "local-exec" {
    command = "echo ${local.test_multi_attach_command_list[count.index]} >> results.txt ; "
  }

}
*/


/*
  Logic to run the OCI CLI commands to do multi-attach of BVol to compute instances
*/
/*
resource "null_resource" "multi_attach_shared_data_bv_to_nsd_nodes" {
  depends_on = [
    oci_core_instance.nsd_node,
    oci_core_volume.shared_data_block_volume,
    null_resource.copy_nsddevices_to_all_server_nodes,
        null_resource.test_multi_attach_shared_data_bv_to_nsd_nodes
  ]
  count = length(local.multi_attach_command_list)


  # 60-200
  provisioner "local-exec" {
    command = "delay=`shuf -i 5-30 -n 1` ; echo $delay ; sleep $delay ;  "
  }
# ${local.multi_attach_command_list[count.index]} ;
}
*/



resource "oci_core_volume_attachment" "shared_data_blockvolume_attach" {
  attachment_type = "iscsi"
  count = length(local.test_multi_attach_command_list)

  instance_id = element(oci_core_instance.nsd_node.*.id, element(split(" ", local.test_multi_attach_command_list[count.index]),0) ,)
  volume_id = element(oci_core_volume.shared_data_block_volume.*.id, ( element(split(" ", local.test_multi_attach_command_list[count.index]),1)  )   )
  is_shareable = true
  
  device       = var.volume_attach_device_mapping[( element(split(" ", local.test_multi_attach_command_list[count.index]),2)  )]


  provisioner "remote-exec" {
    connection {
      agent   = false
      timeout = "30m"
      host    = element(oci_core_instance.nsd_node.*.private_ip, ( element(split(" ", local.test_multi_attach_command_list[count.index]),0) )   )

      user                = var.ssh_user
      private_key         = tls_private_key.ssh.private_key_pem
      bastion_host        = oci_core_instance.bastion[0].public_ip
      bastion_port        = "22"
      bastion_user        = var.ssh_user
      bastion_private_key = tls_private_key.ssh.private_key_pem

    }

    inline = [
      "sudo -s bash -c 'set -x && iscsiadm -m node -o new -T ${self.iqn} -p ${self.ipv4}:${self.port}'",
      "sudo -s bash -c 'set -x && iscsiadm -m node -o update -T ${self.iqn} -n node.startup -v automatic '",
      "sudo -s bash -c 'set -x && iscsiadm -m node -T ${self.iqn} -p ${self.ipv4}:${self.port} -l '",
      "delay=`shuf -i 5-30 -n 1` ; echo $delay ; sleep $delay ;"
    ]
  }
}




/*
  Notify NSD server nodes that multi-attach is complete, so NSD server nodes can continue with their rest of the instance setup logic in cloud-init.
*/
resource "null_resource" "notify_server_nodes_oci_cli_multi_attach_complete" {
  depends_on = [
                 oci_core_volume_attachment.shared_data_blockvolume_attach,
                    null_resource.copy_nsddevices_to_all_server_nodes]
  count      = var.total_nsd_node_pools * var.nsd_nodes_per_pool
  provisioner "remote-exec" {
    connection {
        agent               = false
        timeout             = "30m"
        host                = element(oci_core_instance.nsd_node.*.private_ip, count.index)
        user                = var.ssh_user
        private_key         = tls_private_key.ssh.private_key_pem
        bastion_host        = oci_core_instance.bastion.*.public_ip[0]
        bastion_port        = "22"
        bastion_user        = var.ssh_user
        bastion_private_key = tls_private_key.ssh.private_key_pem
    }
    inline = [
      "set -x",
      "sudo touch /tmp/multi-attach.complete",
    ]
  }
}


