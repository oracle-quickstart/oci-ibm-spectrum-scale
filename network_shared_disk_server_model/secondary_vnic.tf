resource "oci_core_vnic_attachment" "secondary_vnic_attachment" {
  #1# count = (local.dual_nics ? var.total_nsd_node_pools * var.nsd_nodes_per_pool : var.total_nsd_node_pools * var.nsd_nodes_per_pool)
   count = (local.dual_vnic ? var.total_nsd_node_pools * var.nsd_nodes_per_pool : 0)
   create_vnic_details {
#1# subnet_id = oci_core_subnet.privateb.*.id[0]
       subnet_id = local.fs_subnet_id

       assign_public_ip = "false"
       display_name = "${var.nsd_node_hostname_prefix}${format("%01d", count.index+1)}"
       hostname_label = "${var.nsd_node_hostname_prefix}${format("%01d", count.index+1)}"
       # false is default value
       skip_source_dest_check = "false"
   }
   instance_id = element(oci_core_instance.nsd_node.*.id, count.index)

   #Optional
   display_name = "SecondaryVNIC"
   # set to 1, if you want to use 2nd physical NIC for this VNIC
####nic_index = "1"
   #1# nic_index = (local.dual_nics ? (local.dual_nics_hpc_shape ? "0" : "1") : "0")
   nic_index = (local.dual_vnic ? "1" : "0")

}

# dual_nics_ces_node
resource "oci_core_vnic_attachment" "ces_node_secondary_vnic_attachment" {
   # Assume if CES node is needed, a seperate protocol subnet is required
   count = (local.dual_nics_ces_node ? var.ces_node_count : var.ces_node_count)
   #! Change logic to use the below, once whether to run CES node on protocol subnet or not is made
   #! count = (local.dual_vnic_ces ? var.ces_node["node_count"] : 0)
   create_vnic_details {
       #1# subnet_id = oci_core_subnet.privateb.*.id[0]
       subnet_id = local.fs_subnet_id

       assign_public_ip = "false"
       display_name = "${var.ces_node_hostname_prefix}${format("%01d", count.index+1)}"
       hostname_label = "${var.ces_node_hostname_prefix}${format("%01d", count.index+1)}"
       # false is default value
       skip_source_dest_check = "false"
   }
   instance_id = element(oci_core_instance.ces_node.*.id, count.index)

   #Optional
   display_name = "SecondaryVNIC"
   # set to 1, if you want to use 2nd physical NIC for this VNIC
####   nic_index = "1"
   nic_index = (local.dual_nics_ces_node ? (local.dual_nics_ces_hpc_shape ? "0" : "1") : "0")
}


# virtual IP addresses for the CES IP address pool
resource "oci_core_vnic_attachment" "ces_node_virtual_ip_pool_secondary_vnic_attachment" {
   depends_on = [ oci_core_vnic_attachment.ces_node_secondary_vnic_attachment]
   count = var.ces_node_count
   create_vnic_details {
#1# subnet_id = oci_core_subnet.privateprotocol.*.id[0]
       subnet_id = local.protocol_subnet_id

       assign_public_ip = "false"
       display_name = "${var.ces_node_hostname_prefix}vip-pool-${format("%01d", count.index+1)}"
       hostname_label = "${var.ces_node_hostname_prefix}vip-pool-${format("%01d", count.index+1)}"
       # false is default value
       skip_source_dest_check = "false"
   }
   instance_id = element(oci_core_instance.ces_node.*.id, count.index)

   #Optional
   display_name = "SecondaryVNIC"
   # set to 1, if you want to use 2nd physical NIC for this VNIC
   nic_index = "0"
}


