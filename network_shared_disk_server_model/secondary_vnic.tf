resource "oci_core_vnic_attachment" "secondary_vnic_attachment" {
  count = (local.dual_nics ? var.total_nsd_node_pools * var.nsd_nodes_per_pool : var.total_nsd_node_pools * var.nsd_nodes_per_pool)
   create_vnic_details {
       subnet_id = oci_core_subnet.privateb.*.id[0]
       assign_public_ip = "false"
       display_name = "${var.nsd_node["hostname_prefix"]}${format("%01d", count.index+1)}"
       hostname_label = "${var.nsd_node["hostname_prefix"]}${format("%01d", count.index+1)}"
       # false is default value
       skip_source_dest_check = "false"
   }
   instance_id = element(oci_core_instance.nsd_node.*.id, count.index)

   #Optional
   display_name = "SecondaryVNIC"
   # set to 1, if you want to use 2nd physical NIC for this VNIC
####nic_index = "1"
   nic_index = (local.dual_nics ? (local.dual_nics_hpc_shape ? "0" : "1") : "0")
}

# dual_nics_ces_node
resource "oci_core_vnic_attachment" "ces_node_secondary_vnic_attachment" {
   count = (local.dual_nics_ces_node ? var.ces_node["node_count"] : var.ces_node["node_count"])
   create_vnic_details {
       subnet_id = oci_core_subnet.privateb.*.id[0]
       assign_public_ip = "false"
       display_name = "${var.ces_node["hostname_prefix"]}${format("%01d", count.index+1)}"
       hostname_label = "${var.ces_node["hostname_prefix"]}${format("%01d", count.index+1)}"
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
   count = var.ces_node["node_count"]
   create_vnic_details {
       subnet_id = oci_core_subnet.privateprotocol.*.id[0]
       assign_public_ip = "false"
       display_name = "${var.ces_node["hostname_prefix"]}vip-pool-${format("%01d", count.index+1)}"
       hostname_label = "${var.ces_node["hostname_prefix"]}vip-pool-${format("%01d", count.index+1)}"
       # false is default value
       skip_source_dest_check = "false"
   }
   instance_id = element(oci_core_instance.ces_node.*.id, count.index)

   #Optional
   display_name = "SecondaryVNIC"
   # set to 1, if you want to use 2nd physical NIC for this VNIC
   nic_index = "0"
}


