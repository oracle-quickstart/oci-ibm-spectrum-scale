# Gets a list of Availability Domains
data "oci_identity_availability_domains" "ADs" {
  compartment_id = "${var.tenancy_ocid}"
}


data "template_file" "boot_script" {
  template =  "${file("../shared_nothing_scripts/boot.sh.tpl")}"
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
    DiskPerNode="${var.DiskPerNode}"
    DiskSize="${var.DiskSize}"
    InstallerNode = "${var.ServerNodeHostnamePrefix}1"
    PrivateSubnetsFQDN = "${oci_core_virtual_network.ibmss_vcnv3.dns_label}.oraclevcn.com ${oci_core_subnet.private.*.dns_label[0]}.${oci_core_virtual_network.ibmss_vcnv3.dns_label}.oraclevcn.com ${oci_core_subnet.private.*.dns_label[1]}.${oci_core_virtual_network.ibmss_vcnv3.dns_label}.oraclevcn.com ${oci_core_subnet.private.*.dns_label[2]}.${oci_core_virtual_network.ibmss_vcnv3.dns_label}.oraclevcn.com"
    CompanyName="${var.CompanyName}" 
    CompanyID="${var.CompanyID}" 
    CountryCode="${var.CountryCode}" 
    EmailAddress="${var.EmailAddress}"  
  }
}


