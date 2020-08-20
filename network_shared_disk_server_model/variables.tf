###
## Variables.tf for Terraform
## Defines variables and local values
###

variable "vpc_cidr" { default = "10.0.0.0/16" }

variable "total_nsd_node_pools" { default="1" }
/*
  Use 16 block_volumes_per_pool of 800GB each for max throughput, 
  if using BM.Standard2.52 for NSD servers.
*/
variable "block_volumes_per_pool" { default="16" }


# One bastion node is enough
variable "bastion" {
  type = map(string)
  default = {
    shape      = "VM.Standard2.2"
    node_count = 1
    hostname_prefix = "bastion-"
  }
}

# NSD Server nodes variables
variable "nsd_node" {
  type = map(string)
  default = {
    #shape = "BM.DenseIO2.52"
    shape      = "BM.Standard2.52"
    hostname_prefix = "ss-server-"
    }
}


# NSD Block Volumes Disk Configurations. size is in GB.
variable "nsd" {
  type = map(string)
  default = {
    size = "1000"
  }
}

# Client nodes variables
variable "client_node" {
  type = map(string)
  default = {
    shape      = "VM.Standard2.24"
    #shape      = "BM.Standard.E2.64" , VM.DenseIO2.16 VM.Standard2.4
    node_count = 1
    hostname_prefix = "ss-compute-"
    }
}

/*
  Spectrum Scale related variables
*/
/*
  download_url : Should be a http/https link which is accessible from all Spectrum Scale instances we will create. 
  You can use OCI Object Storage bucket with pre-authenticated URL.  
  example: https://objectstorage.us-ashburn-1.oraclecloud.com/p/DLdr-xxxxxxxxxxxxxxxxxxxx/n/hpc/b/spectrum_scale/o/Spectrum_Scale_Data_Management-5.0.3.2-x86_64-Linux-install
  Assuming you have uploaded the spectrum scale software binary to OCI Object storage private bucket. You can create a 
  preauthenticatedrequests using the steps detailed here - https://docs.cloud.oracle.com/en-us/iaas/Content/Object/Tasks/usingpreauthenticatedrequests.htm#usingconsole
  
  Note: The name of the spectrum scale software binary file needs to exactly follow this naming convention. 
  These are the names of the file by default, when you download it. 
  Replace the version number with the one you are using:
  For Spectrum Scale Data Management Edition:  Spectrum_Scale_Data_Management-5.0.3.3-x86_64-Linux-install
  For Spectrum Scale Developer Edition:        Spectrum Scale 5.0.4.1 Developer Edition.zip 
  Once you upload to OCI Object Storage,  the download_url will look like this: 
  https://objectstorage.us-ashburn-1.oraclecloud.com/xxxxxxxx/Spectrum_Scale_Data_Management-5.0.3.3-x86_64-Linux-install
  or 
  https://objectstorage.us-ashburn-1.oraclecloud.com/xxxxxxxx/Spectrum%20Scale%205.0.4.1%20Developer%20Edition.zip
*/
variable "spectrum_scale" {
  type = map(string)
  default = {
    # Make sure the version # matches the version # in the download_url field. 
    version      = "5.0.3.3"
    download_url = "https://xxxxxxxx/Spectrum_Scale_Data_Management-5.0.3.3-x86_64-Linux-install"
    block_size = "2M"
    data_replica  = 1
    metadata_replica = 1
    gpfs_mount_point = "/gpfs/fs1"
    high_availability = false
  }
}


# if high_availability is set to false, then first AD value from the below list will be used to create cluster.
# if high_availability is set to true, then both values from the below list will be used to create cluster.
#variable "availability_domain" { default = [1,2] }
#variable "availability_domain" { default = [2,3] }
variable "availability_domain" { default = [3,1] }


locals {
  site1 = (var.spectrum_scale["high_availability"] ? var.availability_domain[0] - 1 : var.availability_domain[0] - 1)
  site2 = (var.spectrum_scale["high_availability"] ? var.availability_domain[1] - 1 : var.availability_domain[0] - 1)
  dual_nics = (length(regexall("^BM", var.nsd_node["shape"])) > 0 ? true : false)
  #storage_server_dual_nics
  dual_nics_hpc_shape = (length(regexall("HPC2", var.nsd_node["shape"])) > 0 ? true : false)

  dual_vnic = (local.dual_nics ? (local.dual_nics_hpc_shape ? false  : true) : false)


  dual_nics_ces_node = (length(regexall("^BM", var.ces_node["shape"])) > 0 ? true : false)
  dual_nics_ces_hpc_shape = (length(regexall("HPC2", var.ces_node["shape"])) > 0 ? true : false)

  dual_vnic_ces = (local.dual_nics_ces_node ? (local.dual_nics_ces_hpc_shape ? false  : true) : false)

  #vcn_fqdn = (local.dual_nics ? "${oci_core_virtual_network.gpfs.dns_label}.oraclevcn.com" : ""  )
#1#vcn_fqdn = "${oci_core_virtual_network.gpfs.dns_label}.oraclevcn.com"

####
####  privateSubnetsFQDN=(local.dual_nics ? "${oci_core_subnet.private.*.dns_label[0]}.${oci_core_virtual_network.gpfs.dns_label}.oraclevcn.com" : "${oci_core_subnet.private.*.dns_label[0]}.${oci_core_virtual_network.gpfs.dns_label}.oraclevcn.com"  )
####  privateBSubnetsFQDN=(local.dual_nics ? "${oci_core_subnet.privateb.*.dns_label[0]}.${oci_core_virtual_network.gpfs.dns_label}.oraclevcn.com" : "${oci_core_subnet.private.*.dns_label[0]}.${oci_core_virtual_network.gpfs.dns_label}.oraclevcn.com"  )
####  private_protocol_subnet_fqdn=(local.dual_nics ? "${oci_core_subnet.privateprotocol.*.dns_label[0]}.${oci_core_virtual_network.gpfs.dns_label}.oraclevcn.com" : "${oci_core_subnet.private.*.dns_label[0]}.${oci_core_virtual_network.gpfs.dns_label}.oraclevcn.com"  )

#1#  privateSubnetsFQDN=("${oci_core_subnet.private.*.dns_label[0]}.${oci_core_virtual_network.gpfs.dns_label}.oraclevcn.com")
#1#  privateBSubnetsFQDN=("${oci_core_subnet.privateb.*.dns_label[0]}.${oci_core_virtual_network.gpfs.dns_label}.oraclevcn.com")
#1#  private_protocol_subnet_fqdn=("${oci_core_subnet.privateprotocol.*.dns_label[0]}.${oci_core_virtual_network.gpfs.dns_label}.oraclevcn.com")

}


# GPFS Management GUI Node Configurations
# Optional node
variable "mgmt_gui_node" {
  type = map(string)
  default = {
    node_count      = "0"
    shape           = "VM.Standard2.8"
    hostname_prefix = "ss-mgmt-gui-"
  }
}


# Optional node
variable "ces_node" {
  type = map(string)
  default = {
    node_count      = "0"
    shape           = "BM.Standard2.52"
    hostname_prefix = "ss-ces-"
  }
}

# Optional node
variable "windows_smb_client" {
  type = map(string)
  default = {
    shape                   = "VM.Standard2.4"
    node_count              = 0
    hostname_prefix         = "ss-smb-client-"
    # 256 GB - Required boot volume size for windows
    boot_volume_size_in_gbs = "256"
  }
}

# You can use the below,  no need to change them for non-production use.
variable "callhome" {
  type = map(string)
  default = {
    company_name = "Company Name"
    company_id   = "1234567"
    country_code = "US"
    emailaddress = "name@email.com"
  }
}

##################################################
## Variables which should not be changed by user
##################################################

variable "nsd_nodes_per_pool" { default="2" }

# Please do not change.  The first nsd node is used for cluster deployment
variable "installer_node" { default = "1" }

variable "scripts_directory" { default = "../network_shared_disk_server_model_scripts" }


###############

variable "tenancy_ocid" {}
variable "user_ocid" {}
variable "fingerprint" {}
variable "private_key_path" {}
variable "region" { default = "uk-london-1" }

variable "compartment_ocid" {}
variable "ssh_public_key" {}
variable "ssh_private_key" {}
variable "ssh_private_key_path" {}

/*
  For instances created using Oracle Linux and CentOS images, the user name opc is created automatically.
  For instances created using the Ubuntu image, the user name ubuntu is created automatically.
  Spectrum Scale works with Ubuntu on OCI, but this automation does not support it.  TODO: Future work.  
  variable "ssh_user" { default = "ubuntu" }
*/
variable "ssh_user" { default = "opc" }


# https://docs.cloud.oracle.com/iaas/images/image/09f3e226-681f-405d-bc27-070896f44973/
# https://docs.cloud.oracle.com/iaas/images/windows-server-2016-vm/
# Windows-Server-2016-Standard-Edition-VM-Gen2-2019.07.15-0
variable "w_images" {
  type = map(string)
  default = {
    ap-mumbai-1 = "ocid1.image.oc1.ap-mumbai-1.aaaaaaaabebjqpcnnnd5eojzto7twrw6wphiruxhhvj7nfve7q4cjtkyl7eq"
    ap-seoul-1 = "ocid1.image.oc1.ap-seoul-1.aaaaaaaavwcdcjgqrsi5antj4lrqnnpmiivijcv22vjvranz5v3ozntgt6na"
    ap-tokyo-1 = "ocid1.image.oc1.ap-tokyo-1.aaaaaaaahs5qx52v3a4n72o42v3eonrrj2dhwokni3rmv3ym5l32actm6tma"
    ca-toronto-1 = "ocid1.image.oc1.ca-toronto-1.aaaaaaaa4ktddg54ca2gqvbusjfnpjfk4n4yvkoygpsphfwolapwep7v63qq"
    eu-frankfurt-1 = "ocid1.image.oc1.eu-frankfurt-1.aaaaaaaa4qimrpdogtno7c6h3dh3j66mnpjzpeufn6he6lydim3ftzto7bkq"
    eu-zurich-1 = "ocid1.image.oc1.eu-zurich-1.aaaaaaaaorf2gr7rdxhhliesbrqx3ktomesmghgdnysqwh5tpfcd2ge2y2za"
    uk-london-1 = "ocid1.image.oc1.uk-london-1.aaaaaaaao7li5qsxa6wdzysoq4pz7marynzyff57eu4uilv4tgkezs5djvxa"
    us-ashburn-1 = "ocid1.image.oc1.iad.aaaaaaaaokudtg52d3palj2uq5aeli7rtl3uedbbbwlb7btv4upj34rdhbma"
    us-langley-1 = "ocid1.image.oc2.us-langley-1.aaaaaaaa6ijhwlviofxlohfhp6um57tn3d2owjqa2amh5v4euhwd5rkysaeq"
    us-luke-1 = "ocid1.image.oc2.us-luke-1.aaaaaaaaskxgygvujodzad4ghkelizqfjaq5m5sbjvg7ew5mydrkylcofyma"
    us-phoenix-1 = "ocid1.image.oc1.phx.aaaaaaaae7gdb5asazzy3fx2k4magi3mbvp7natm6xzgbjfyzcvnxns2uvwa"
  }
}


/*
See https://docs.us-phoenix-1.oraclecloud.com/images/ or https://docs.cloud.oracle.com/iaas/images/
Oracle-provided image "CentOS-7-2019.08.26-0"
https://docs.cloud.oracle.com/iaas/images/image/ea67dd20-b247-4937-bfff-894962212415/
*/
/* imagesCentOS */
variable "images" {
  type = map(string)
  default = {
    ap-mumbai-1 = "ocid1.image.oc1.ap-mumbai-1.aaaaaaaabfqn5vmh3pg6ynpo6bqdbg7fwruu7qgbvondjic5ccr4atlj4j7q"
    ap-seoul-1   = "ocid1.image.oc1.ap-seoul-1.aaaaaaaaxfeztdrbpn452jk2yln7imo4leuhlqicoovoqu7cxqhkr3j2zuqa"
    ap-sydney-1    = "ocid1.image.oc1.ap-sydney-1.aaaaaaaanrubykp6xrff5xzd6gu2g6ul6ttnyoxgaeeq434urjz5j6wfq4fa"
    ap-tokyo-1   = "ocid1.image.oc1.ap-tokyo-1.aaaaaaaakkqtoabcjigninsyalinvppokmgaza6amynam3gs2ldelpgesu6q"
    ca-toronto-1 = "ocid1.image.oc1.ca-toronto-1.aaaaaaaab4hxrwlcs4tniwjr4wvqocmc7bcn3apnaapxabyg62m2ynwrpe2a"
    eu-frankfurt-1 = "ocid1.image.oc1.eu-frankfurt-1.aaaaaaaawejnjwwnzapqukqudpczm4pwtpcsjhohl7qcqa5vzd3gxwmqiq3q"
    eu-zurich-1   = "ocid1.image.oc1.eu-zurich-1.aaaaaaaa7hdfqf54qcnu3bizufapscopzdlxp54yztuxauxyraprxnqjj7ia"
    sa-saopaulo-1 = "ocid1.image.oc1.sa-saopaulo-1.aaaaaaaa2iqobvkeowx4n2nqsgy32etohkw2srqireqqk3bhn6hv5275my6a"
    uk-london-1    = "ocid1.image.oc1.uk-london-1.aaaaaaaakgrjgpq3jej3tyqfwsyk76tl25zoflqfjjuuv43mgisrmhfniofq"
    us-ashburn-1   = "ocid1.image.oc1.iad.aaaaaaaa5phjudcfeyomogjp6jjtpcl3ozgrz6s62ltrqsfunejoj7cqxqwq"
    us-phoenix-1   = "ocid1.image.oc1.phx.aaaaaaaag7vycom7jhxqxfl6rxt5pnf5wqolksl6onuqxderkqrgy4gsi3hq"
  }
}

variable "imagesCentos76" {
  type = map(string)
  default = {
    /*
      See https://docs.us-phoenix-1.oraclecloud.com/images/ or https://docs.cloud.oracle.com/iaas/images/
      Oracle-provided image "CentOS-7-2018.11.16-0"
      https://docs.cloud.oracle.com/iaas/images/image/66a17669-8a67-4b43-924a-78d8ae49f609/
    */
    eu-frankfurt-1 = "ocid1.image.oc1.eu-frankfurt-1.aaaaaaaatbfzohfzwagb5eplk5abjifwmr5bpytuo2pgyufflpkdfkkb3eca"
    us-ashburn-1   = "ocid1.image.oc1.iad.aaaaaaaa3p2d4bzgz4gw435tw3522u4d3enh7jwlwpymfgqwp6hrhebs4s2q"
    uk-london-1    = "ocid1.image.oc1.uk-london-1.aaaaaaaaktvxlhhjs3k57fbloubrbuju7vdyaivdw5pclmva2kwhqhqlewbq"
    us-phoenix-1   = "ocid1.image.oc1.phx.aaaaaaaavzt7r56xh2lj2w7ibqbkvumxbqr2z2jswoma3qjbunu7wj63rigq"
  }
}

# Oracle-Linux-7.6-2019.05.28-0
# https://docs.cloud.oracle.com/iaas/images/image/6180a2cb-be6c-4c78-a69f-38f2714e6b3d/
variable "imagesOL" {
  type = map(string)
  default = {
    /*
      See https://docs.us-phoenix-1.oraclecloud.com/images/ or https://docs.cloud.oracle.com/iaas/images/
      Oracle-provided image "CentOS-7-2018.11.16-0"
      https://docs.cloud.oracle.com/iaas/images/image/66a17669-8a67-4b43-924a-78d8ae49f609/
    */
    us-ashburn-1   = "ocid1.image.oc1.iad.aaaaaaaaj6pcmnh6y3hdi3ibyxhhflvp3mj2qad4nspojrnxc6pzgn2w3k5q"
    us-phoenix-1   = "ocid1.image.oc1.phx.aaaaaaaa2wadtmv6j6zboncfobau7fracahvweue6dqipmcd5yj6s54f3wpq"
  }
}




variable "use_existing_vcn" {
  default = "false"
}

variable "vcn_id" {
  default = "ocid1.vcn.oc1.iad.amaaaaaa7rhxvoaaufglmdw7jvdeeuix3ag6zz5svee4snyzmxabb5q7hpmq"
}

variable "bastion_subnet_id" {
  default = "ocid1.subnet.oc1.iad.aaaaaaaaxkfuasory4cwkl7jyrole5gpmq5nmdnxtbmnmuxhs5rgsdmubxaq"
}

variable "storage_subnet_id" {
  default = "ocid1.subnet.oc1.iad.aaaaaaaafdditphyjamahq4eveevpci2cifpfsj53fh3a4kfw5p6ba6ymkmq"
}

variable "fs_subnet_id" {
  default = "ocid1.subnet.oc1.iad.aaaaaaaa3epu2pbkwi4ae3pvn2exeom3pmzypm7w3lunndubburic2xlte7a"
}

variable "protocol_subnet_id" {
  default = "ocid1.subnet.oc1.iad.aaaaaaaa3epu2pbkwi4ae3pvn2exeom3pmzypm7w3lunndubburic2xlte7a"
}

locals {
  bastion_subnet_id = var.use_existing_vcn ? var.bastion_subnet_id : element(concat(oci_core_subnet.public.*.id, [""]), 0)
  storage_subnet_id   = var.use_existing_vcn ? var.storage_subnet_id : element(concat(oci_core_subnet.storage.*.id, [""]), 0)
  fs_subnet_id        = var.use_existing_vcn ? var.fs_subnet_id : local.dual_vnic ? element(concat(oci_core_subnet.fs.*.id, [""]), 0) :  element(concat(oci_core_subnet.storage.*.id, [""]), 0)
  client_subnet_id    = local.fs_subnet_id 
  protocol_subnet_id  = var.use_existing_vcn ? var.protocol_subnet_id : element(concat(oci_core_subnet.protocol_subnet.*.id, [""]), 0)

  storage_subnet_domain_name=("${data.oci_core_subnet.storage_subnet.dns_label}.${data.oci_core_vcn.vcn.dns_label}.oraclevcn.com" )
  filesystem_subnet_domain_name= ( local.dual_vnic ? "${data.oci_core_subnet.fs_subnet.dns_label}.${data.oci_core_vcn.vcn.dns_label}.oraclevcn.com" : "${data.oci_core_subnet.storage_subnet.dns_label}.${data.oci_core_vcn.vcn.dns_label}.oraclevcn.com" )
  vcn_domain_name=("${data.oci_core_vcn.vcn.dns_label}.oraclevcn.com" )
  protocol_subnet_domain_name= ( "${data.oci_core_subnet.protocol_subnet.dns_label}.${data.oci_core_vcn.vcn.dns_label}.oraclevcn.com" )

}
