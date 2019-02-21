# Gets a list of Availability Domains
data "oci_identity_availability_domains" "ADs" {
  compartment_id = "${var.tenancy_ocid}"
}


data "template_file" "boot_script" {
  template =  "${file("../scripts/boot.sh.tpl")}"
  vars {
    PrivateSubnetsFQDN = "${oci_core_virtual_network.ibmss_vcn.dns_label}.oraclevcn.com ${oci_core_subnet.private.*.dns_label[0]}.${oci_core_virtual_network.ibmss_vcn.dns_label}.oraclevcn.com ${oci_core_subnet.private.*.dns_label[1]}.${oci_core_virtual_network.ibmss_vcn.dns_label}.oraclevcn.com ${oci_core_subnet.private.*.dns_label[2]}.${oci_core_virtual_network.ibmss_vcn.dns_label}.oraclevcn.com"
  }
}

/*
data "template_file" "worker_boot_script" {
  template =  "${file("../scripts/worker_boot.sh.tpl")}"
  vars {
    tableau_version = "${var.tableau_version}"
    Username = "${var.username}"
    Password = "${var.password}"
    TableauServerAdminUser = "${var.tableau_server_admin_user}"
    TableauServerAdminPassword = "${var.tableau_server_admin_password}"
    TableauPrimaryNodePrivateIP = "${oci_core_instance.tableau_server.*.private_ip[0]}"
    PrivateSubnetsFQDN = "${oci_core_virtual_network.ibmss_vcn.dns_label}.oraclevcn.com ${oci_core_subnet.private.*.dns_label[0]}.${oci_core_virtual_network.ibmss_vcn.dns_label}.oraclevcn.com ${oci_core_subnet.private.*.dns_label[1]}.${oci_core_virtual_network.ibmss_vcn.dns_label}.oraclevcn.com ${oci_core_subnet.private.*.dns_label[2]}.${oci_core_virtual_network.ibmss_vcn.dns_label}.oraclevcn.com"
  }
}
*/
/*
data "oci_core_vnic" "bastion_vnic" {
  vnic_id = "${lookup(data.oci_core_vnic_attachments.bastion_vnics.vnic_attachments[0],"vnic_id")}"
}


data "oci_core_vnic_attachments" "bastion_vnics" {
  compartment_id      = "${var.compartment_ocid}"
  availability_domain = "${lookup(data.oci_identity_availability_domains.ADs.availability_domains[var.AD - 1],"name")}"
  instance_id         = "${oci_core_instance.bastion.*.id[0]}"
}
*/

