# Gets a list of Availability Domains
data "oci_identity_availability_domains" "ADs" {
  compartment_id = "${var.tenancy_ocid}"
}

/*
data "template_file" "boot_script" {
  template =  "${file("../direct_attached_scripts/boot.sh.tpl")}"
  vars = {
    version = "${var.ibm_ss_version}"
    downloadUrl = "${var.software_download_url}"
    sshPrivateKey = "${var.ssh_private_key}"
    sshPublicKey = "${var.ssh_public_key}"
    clientNodeCount = "${var.ComputeNodeCount}"
    clientNodeHostnamePrefix = "${var.ComputeNodeHostnamePrefix}"
    blockSize="${var.BlockSize}"
    dataReplica="${var.DataReplica}"
    metadataReplica="2"
    gpfsMountPoint="${var.GpfsMountPoint}"
    sharedDataDiskCount="${var.SharedData["Count"]}"
    installerNode = "${var.ComputeNodeHostnamePrefix}1"
    privateSubnetsFQDN = "${oci_core_virtual_network.ibmss_vcnv3.dns_label}.oraclevcn.com ${oci_core_subnet.private.*.dns_label[0]}.${oci_core_virtual_network.ibmss_vcnv3.dns_label}.oraclevcn.com ${oci_core_subnet.private.*.dns_label[1]}.${oci_core_virtual_network.ibmss_vcnv3.dns_label}.oraclevcn.com ${oci_core_subnet.private.*.dns_label[2]}.${oci_core_virtual_network.ibmss_vcnv3.dns_label}.oraclevcn.com"
  }
}
*/


