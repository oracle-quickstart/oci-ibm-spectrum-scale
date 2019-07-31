resource "oci_core_vnic_attachment" "secondary_vnic_attachment" {
   count               = "${var.ServerNodeCount}"
   #Required
   create_vnic_details {
       #Required
       subnet_id = "${oci_core_subnet.privateb.*.id[var.AD - 1]}"

       #Optional
       assign_public_ip = "false"
       #defined_tags = "${var.vnic_attachment_create_vnic_details_defined_tags}"
       display_name = "${var.ServerNodeHostnamePrefix}${format("%01d", count.index+1)}"
       #freeform_tags = "${var.vnic_attachment_create_vnic_details_freeform_tags}"
       hostname_label = "${var.ServerNodeHostnamePrefix}${format("%01d", count.index+1)}"
       #private_ip = "${var.vnic_attachment_create_vnic_details_private_ip}"
       # false is default value
       skip_source_dest_check = "false"
   }
   instance_id = "${element(oci_core_instance.ServerNode.*.id, count.index)}"

   #Optional
   display_name = "SecondaryVNIC"
   # set to 1, if you want to use 2nd physical NIC for this VNIC
   nic_index = "1"
}
