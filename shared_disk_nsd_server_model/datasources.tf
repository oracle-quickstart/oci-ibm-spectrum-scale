# Gets a list of Availability Domains
data "oci_identity_availability_domains" "ADs" {
  compartment_id = "${var.tenancy_ocid}"
}


data "template_file" "boot_script" {
  template =  "${file("${var.scripts_directory}/boot.sh.tpl")}"
  vars {
    IBMSSVersion = "${var.ibm_ss_version}"
    SoftwareDownloadURL = "${var.software_download_url}"
    SSHPrivateKey = "${var.ssh_private_key}"
    SSHPublicKey = "${var.ssh_public_key}"
    ServerNodeCount = "${var.ServerNodeCount}"
    ServerNodeHostnamePrefix = "${var.ServerNodeHostnamePrefix}"
    ComputeNodeCount = "${var.ComputeNodeCount}"
    ComputeNodeHostnamePrefix = "${var.ComputeNodeHostnamePrefix}"
    BlockSize="${var.BlockSize}"
    DataReplica="${var.DataReplica}"
    GpfsMountPoint="${var.GpfsMountPoint}"
    SharedDataDiskCount="${var.SharedData["Count"]}"
    InstallerNode = "${var.ServerNodeHostnamePrefix}1"
    PrivateSubnetsFQDN = "${oci_core_virtual_network.ibmss_vcnv3.dns_label}.oraclevcn.com ${oci_core_subnet.private.*.dns_label[0]}.${oci_core_virtual_network.ibmss_vcnv3.dns_label}.oraclevcn.com ${oci_core_subnet.private.*.dns_label[1]}.${oci_core_virtual_network.ibmss_vcnv3.dns_label}.oraclevcn.com ${oci_core_subnet.private.*.dns_label[2]}.${oci_core_virtual_network.ibmss_vcnv3.dns_label}.oraclevcn.com"
    PrivateBSubnetsFQDN = "${oci_core_virtual_network.ibmss_vcnv3.dns_label}.oraclevcn.com ${oci_core_subnet.privateb.*.dns_label[0]}.${oci_core_virtual_network.ibmss_vcnv3.dns_label}.oraclevcn.com ${oci_core_subnet.privateb.*.dns_label[1]}.${oci_core_virtual_network.ibmss_vcnv3.dns_label}.oraclevcn.com ${oci_core_subnet.privateb.*.dns_label[2]}.${oci_core_virtual_network.ibmss_vcnv3.dns_label}.oraclevcn.com"
    CompanyName="${var.CompanyName}" 
    CompanyID="${var.CompanyID}" 
    CountryCode="${var.CountryCode}" 
    EmailAddress="${var.EmailAddress}"  
  }
}


data "template_file" "mgmt_gui_boot_script" {
  template =  "${file("${var.scripts_directory}/mgmt_gui_boot.sh.tpl")}"
  vars {
    IBMSSVersion = "${var.ibm_ss_version}"
    SoftwareDownloadURL = "${var.software_download_url}"
    SSHPrivateKey = "${var.ssh_private_key}"
    SSHPublicKey = "${var.ssh_public_key}"
    ServerNodeCount = "${var.ServerNodeCount}"
    ServerNodeHostnamePrefix = "${var.ServerNodeHostnamePrefix}"
    ComputeNodeCount = "${var.ComputeNodeCount}"
    ComputeNodeHostnamePrefix = "${var.ComputeNodeHostnamePrefix}"
    GPFSMgmtGUINodeCount = "${var.GPFSMgmtGUINodeCount}"
    GPFSMgmtGUINodeHostnamePrefix = "${var.GPFSMgmtGUINodeHostnamePrefix}"
    BlockSize="${var.BlockSize}"
    DataReplica="${var.DataReplica}"
    GpfsMountPoint="${var.GpfsMountPoint}"
    SharedDataDiskCount="${var.SharedData["Count"]}"
    InstallerNode = "${var.ServerNodeHostnamePrefix}1"
    PrivateSubnetsFQDN = "${oci_core_virtual_network.ibmss_vcnv3.dns_label}.oraclevcn.com ${oci_core_subnet.private.*.dns_label[0]}.${oci_core_virtual_network.ibmss_vcnv3.dns_label}.oraclevcn.com ${oci_core_subnet.private.*.dns_label[1]}.${oci_core_virtual_network.ibmss_vcnv3.dns_label}.oraclevcn.com ${oci_core_subnet.private.*.dns_label[2]}.${oci_core_virtual_network.ibmss_vcnv3.dns_label}.oraclevcn.com"
    PrivateBSubnetsFQDN = "${oci_core_virtual_network.ibmss_vcnv3.dns_label}.oraclevcn.com ${oci_core_subnet.privateb.*.dns_label[0]}.${oci_core_virtual_network.ibmss_vcnv3.dns_label}.oraclevcn.com ${oci_core_subnet.privateb.*.dns_label[1]}.${oci_core_virtual_network.ibmss_vcnv3.dns_label}.oraclevcn.com ${oci_core_subnet.privateb.*.dns_label[2]}.${oci_core_virtual_network.ibmss_vcnv3.dns_label}.oraclevcn.com"
    CompanyName="${var.CompanyName}" 
    CompanyID="${var.CompanyID}" 
    CountryCode="${var.CountryCode}" 
    EmailAddress="${var.EmailAddress}"  
  }
}

