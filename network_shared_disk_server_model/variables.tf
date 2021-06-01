###
## Variables.tf for Terraform
## Defines variables and local values
###

variable vpc_cidr { default = "10.0.0.0/16" }
# Subnet IP Range/CIDR to use for regional public subnet. Example: 10.0.0.0/24. Must be within VCN subnet.
variable bastion_subnet_cidr { default = "10.0.0.0/24" }
# Subnet IP Range/CIDR to use for regional private subnet. This will be the primary subnet used by  NSD file servers to access boot/OS disk and network attached data Block Volumes. Example: 10.0.3.0/24. Must be within VCN subnet.
variable storage_subnet_cidr { default = "10.0.3.0/24" }
# Only set this value, if you plan to use Bare metal compute shapes (except BM.HPC2.36) for NSD file servers. This 2nd private regional subnet will be used to create a secondary VNIC on file servers using 2nd physical NIC to achieve highest performance. Example: 10.0.6.0/24. Must be within VCN subnet.
variable fs_subnet_cidr { default = "10.0.6.0/24" }
variable protocol_subnet_cidr { default = "10.0.9.0/24" }



variable total_nsd_node_pools { default="1" }

/*
  Use 16 block_volumes_per_pool of 800GB each for max throughput, 
  if using BM.Standard2.52 for NSD servers.
  OCI Block Volumes are used for network shared disks (NSD)
*/
variable block_volumes_per_pool { default="16" }

# NSD Block Volumes Disk Configurations. size is in GB.
variable nsd_size { default = "1000" }
# High, Balanced, Low
variable nsd_perf_tier  { default = "Balanced" }




# One bastion node is enough
variable bastion_shape { default = "VM.Standard2.2" }
variable bastion_node_count  { default = 1 }
variable bastion_hostname_prefix  { default = "bastion-" }
variable bastion_boot_volume_size  { default = "100" }


# NSD Server nodes variables
variable nsd_node_shape { default = "BM.Standard2.52" }
variable nsd_node_hostname_prefix { default = "ss-server-" }



# Client nodes variables
variable create_compute_nodes { default = "false" }
variable client_node_shape { default = "VM.Standard2.24" }
# "BM.Standard.E2.64" , VM.DenseIO2.16 VM.Standard2.4
variable client_node_count  { default = 1 }
variable client_node_hostname_prefix  { default = "ss-compute-" }



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
  Once you upload to OCI Object Storage,  the download_url will look like this: https://objectstorage.us-ashburn-1.oraclecloud.com/xxxxxxxx/Spectrum_Scale_Data_Management-5.0.3.3-x86_64-Linux-install or https://objectstorage.us-ashburn-1.oraclecloud.com/xxxxxxxx/Spectrum%20Scale%205.0.4.1%20Developer%20Edition.zip
*/

# Make sure the version # matches the version # in the download_url field.
variable spectrum_scale_version { default = "5.0.3.3" }
variable spectrum_scale_download_url { default = "https://xxxxxxxx/Spectrum_Scale_Data_Management-5.0.3.3-x86_64-Linux-install" }
variable spectrum_scale_block_size { default = "2M" }
variable spectrum_scale_data_replica { default = 1 }
variable spectrum_scale_metadata_replica { default = 1 }
variable spectrum_scale_gpfs_mount_point { default = "/gpfs/fs1" }




# This is currently used for Terraform deployment.
# Valid values for Availability Domain: 0,1,2, if the region has 3 ADs, else use 0.
variable ad_number {
  default = "-1"
}

# Not used for normal terraform apply, added for ORM deployments.
variable ad_name {
  default = ""
}

locals {
  # If ad_number is non-negative use it for AD lookup, else use ad_name.
  # Allows for use of ad_number in TF deploys, and ad_name in ORM.
  # Use of max() prevents out of index lookup call.
  ad = var.ad_number >= 0 ? lookup(data.oci_identity_availability_domains.ADs.availability_domains[max(0,var.ad_number)],"name") : var.ad_name

  dual_nics = (length(regexall("^BM", var.nsd_node_shape)) > 0 ? true : false)
  #storage_server_dual_nics
  dual_nics_hpc_shape = (length(regexall("HPC2", var.nsd_node_shape)) > 0 ? true : false)

  dual_vnic = (local.dual_nics ? (local.dual_nics_hpc_shape ? false  : true) : false)


  dual_nics_ces_node = (length(regexall("^BM", var.ces_node_shape)) > 0 ? true : false)
  dual_nics_ces_hpc_shape = (length(regexall("HPC2", var.ces_node_shape)) > 0 ? true : false)

  dual_vnic_ces = (local.dual_nics_ces_node ? (local.dual_nics_ces_hpc_shape ? false  : true) : false)


}


# GPFS Management GUI Node Configurations
# Optional node
variable create_gui_nodes { default = "false" }
variable mgmt_gui_node_count { default = 0 }
variable mgmt_gui_node_shape { default = "VM.Standard2.8" }
variable mgmt_gui_node_hostname_prefix { default = "ss-mgmt-gui-" }

# Optional node
variable create_ces_nodes { default = "false" }
variable ces_node_count { default = 0 }
variable ces_node_shape { default = "BM.Standard2.52" }
variable ces_node_hostname_prefix { default = "ss-ces-" }


# Optional node
variable create_win_smb_client_nodes { default = "false" }
variable windows_smb_client_node_count { default = 0 }
variable windows_smb_client_shape { default = "VM.Standard2.4" }
variable windows_smb_client_hostname_prefix { default = "ss-smb-client-" }
# 256 GB - Required boot volume size for windows
variable windows_smb_client_boot_volume_size_in_gbs { default = "256" }




##################################################
## Variables which should not be changed by user
##################################################

variable nsd_nodes_per_pool { default="2" }

# Please do not change.  The first nsd node is used for cluster deployment
variable installer_node { default = "1" }

#variable scripts_directory { default = "../network_shared_disk_server_model_scripts" }
variable scripts_directory { default = "scripts" }


###############

variable tenancy_ocid {}
variable region {}
variable compartment_ocid {}
variable ssh_public_key {}

/*
  For instances created using Oracle Linux and CentOS images, the user name opc is created automatically.
  For instances created using the Ubuntu image, the user name ubuntu is created automatically.
  Spectrum Scale works with Ubuntu on OCI, but this automation does not support it.  TODO: Future work.  
  variable ssh_user { default = "ubuntu" }
*/
variable ssh_user { default = "opc" }



# https://docs.cloud.oracle.com/iaas/images/image/09f3e226-681f-405d-bc27-070896f44973/
# https://docs.cloud.oracle.com/iaas/images/windows-server-2016-vm/
# Windows-Server-2016-Standard-Edition-VM-Gen2-2019.07.15-0
variable w_images {
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
# CentOS7.8.2003  -  3.10.0-1127.10.1.el7.x86_64
variable images {
    type = map(string)
    default = {
        // See https://docs.us-phoenix-1.oraclecloud.com/images/ or https://docs.cloud.oracle.com/iaas/images/
        // Oracle-provided image "CentOS-7-2020.06.16-0"
        // https://docs.oracle.com/en-us/iaas/images/image/38c87774-4b0a-440a-94b2-c321af1824e4/
	  us-ashburn-1 = "ocid1.image.oc1.iad.aaaaaaaasa5eukeizlabgietiktm7idhpegni42d4d3xz7kvi6nyao5aztlq"
	  us-phoenix-1 = "ocid1.image.oc1.phx.aaaaaaaajw5o3qf7cha2mgov5vxnwyctmcy4eqayy7o4w7s6cqeyppqd3smq"
      eu-frankfurt-1 = "ocid1.image.oc1.eu-frankfurt-1.aaaaaaaamrybyxlwxmfi3sqrcizm7npj3smngwku524yytyoxm7lqqkardaq"
    }
}
*/

/* RHCK OL79 image - custom
   Oracle-Linux-7.9-2021.04.09-0-K3.10.0-1160.21.1.el7.x86_64-noselinux
*/
variable images {
    type = map(string)
    default = {
      eu-frankfurt-1 = "ocid1.image.oc1.eu-frankfurt-1.aaaaaaaanwv3rcimife7nmc5fg76n5e5mrqi2npgbyd73vw3vzvgvfgbsaza"
      us-ashburn-1 = "ocid1.image.oc1.iad.aaaaaaaayi5p6rjcnrarhfuthvpiun6fddvgpvpjqfejkc72drtwbfpftugq"
    }
}

variable use_existing_vcn {
  default = "false"
}

variable vcn_id {
  default = "ocid1.vcn.oc1.iad.amaaaaaa7rhxvoaaufglmdw7jvdeeuix3ag6zz5svee4snyzmxabb5q7hpmq"
}

variable bastion_subnet_id {
  default = "ocid1.subnet.oc1.iad.aaaaaaaaxkfuasory4cwkl7jyrole5gpmq5nmdnxtbmnmuxhs5rgsdmubxaq"
}

variable storage_subnet_id {
  default = "ocid1.subnet.oc1.iad.aaaaaaaafdditphyjamahq4eveevpci2cifpfsj53fh3a4kfw5p6ba6ymkmq"
}

variable fs_subnet_id {
  default = "ocid1.subnet.oc1.iad.aaaaaaaa3epu2pbkwi4ae3pvn2exeom3pmzypm7w3lunndubburic2xlte7a"
}

variable protocol_subnet_id {
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


variable volume_type_vpus_per_gb_mapping {
  type = map(string)
  default = {
    "High"     = 20
    "Balanced" = 10
    "Low"      = 0
    "None"     = -1
  }
}

variable volume_attach_device_mapping {
  type = map(string)
  default = {
    "0" = "/dev/oracleoci/oraclevdb"
    "1" = "/dev/oracleoci/oraclevdc"
    "2" = "/dev/oracleoci/oraclevdd"
    "3" = "/dev/oracleoci/oraclevde"
    "4" = "/dev/oracleoci/oraclevdf"
    "5" = "/dev/oracleoci/oraclevdg"
    "6" = "/dev/oracleoci/oraclevdh"
    "7" = "/dev/oracleoci/oraclevdi"
    "8" = "/dev/oracleoci/oraclevdj"
    "9" = "/dev/oracleoci/oraclevdk"
    "10" = "/dev/oracleoci/oraclevdl"
    "11" = "/dev/oracleoci/oraclevdm"
    "12" = "/dev/oracleoci/oraclevdn"
    "13" = "/dev/oracleoci/oraclevdo"
    "14" = "/dev/oracleoci/oraclevdp"
    "15" = "/dev/oracleoci/oraclevdq"
    "16" = "/dev/oracleoci/oraclevdr"
    "17" = "/dev/oracleoci/oraclevds"
    "18" = "/dev/oracleoci/oraclevdt"
    "19" = "/dev/oracleoci/oraclevdu"
    "20" = "/dev/oracleoci/oraclevdv"
    "21" = "/dev/oracleoci/oraclevdw"
    "22" = "/dev/oracleoci/oraclevdx"
    "23" = "/dev/oracleoci/oraclevdy"
    "24" = "/dev/oracleoci/oraclevdz"
    "25" = "/dev/oracleoci/oraclevdaa"
    "26" = "/dev/oracleoci/oraclevdab"
    "27" = "/dev/oracleoci/oraclevdac"
    "28" = "/dev/oracleoci/oraclevdad"
    "29" = "/dev/oracleoci/oraclevdae"
    "30" = "/dev/oracleoci/oraclevdaf"
    "31" = "/dev/oracleoci/oraclevdag"
  }
}

# Please do not change them. These are for multi-attach block volume Terraform logic.
variable total_nsd_node_pools_list {
  type = list(number)
  default = [0,1,2,3,4,5,6,7,8,9,10,11,12,13,14]
}
variable nsd_nodes_per_pool_list {
  type = list(number)
  default = [0,1,2]
}
variable block_volumes_per_pool_list {
  type = list(number)
  default = [0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31]
}


variable cloudinit_ps1 {
  default = "cloudinit.ps1"
}

variable cloudinit_config {
  default = "cloudinit.yml"
}

variable setup_ps1 {
  default = "setup.ps1"
}

variable userdata {
  default = "userdata"
}

