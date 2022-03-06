###
## Variables.tf for Terraform
###

variable "tenancy_ocid" {}
variable "user_ocid" {}
variable "fingerprint" {}
variable "private_key_path" {}
variable "region" { default = "us-phoenix-1" }

variable "compartment_ocid" {}
variable "ssh_public_key" {}
variable "ssh_private_key" {}

variable "ssh_private_key_path" {}

# For instances created using Oracle Linux and CentOS images, the user name opc is created automatically.
# For instances created using the Ubuntu image, the user name ubuntu is created automatically.
# The ubuntu user has sudo privileges and is configured for remote access over the SSH v2 protocol using RSA keys. The SSH public keys that you specify while creating instances are added to the /home/ubuntu/.ssh/authorized_keys file.
# For more details: https://docs.cloud.oracle.com/iaas/Content/Compute/References/images.htm#one
variable "ssh_user" { default = "opc" }
# For Ubuntu images,  set to ubuntu. 
# variable "ssh_user" { default = "ubuntu" }


variable "AD" { default = "3" }

variable "vpc_cidr" { default = "10.0.0.0/16" }


# CentOS7.8.2003  -  3.10.0-1127.10.1.el7.x86_64
# oracle-cloud-agent yum install command fails to install unified monitoring, but it hangs yum and prevents any other yum command to run.

variable "InstanceImageOCID" {
  type = map(string)
    default = {
        // See https://docs.us-phoenix-1.oraclecloud.com/images/ or https://docs.cloud.oracle.com/iaas/images/
        // Oracle-provided image "CentOS-7-2020.06.16-0"
        // https://docs.oracle.com/en-us/iaas/images/image/38c87774-4b0a-440a-94b2-c321af1824e4/
	  us-ashburn-1 = "ocid1.image.oc1.iad.aaaaaaaasa5eukeizlabgietiktm7idhpegni42d4d3xz7kvi6nyao5aztlq"
	  us-phoenix-1 = "ocid1.image.oc1.phx.aaaaaaaajw5o3qf7cha2mgov5vxnwyctmcy4eqayy7o4w7s6cqeyppqd3smq"
    }
}



/*
# CentOS7.6.1810
variable "InstanceImageOCID" {
  type = map(string)
  default = {
        // See https://docs.us-phoenix-1.oraclecloud.com/images/ or https://docs.cloud.oracle.com/iaas/images/
        // Oracle-provided image "CentOS-7-2018.08.15-0"
	eu-frankfurt-1 = "ocid1.image.oc1.eu-frankfurt-1.aaaaaaaatz6zixwltzswnmzi2qxdjcab6nw47xne4tco34kn6hltzdppmada" 
	us-ashburn-1 = "ocid1.image.oc1.iad.aaaaaaaaxwo4ovajb6fr5jih6czpffacijuwgwvavhamk5pk5ixkx52yu7da"
	uk-london-1 = "ocid1.image.oc1.uk-london-1.aaaaaaaai3czrt22cbu5uytpci55rcy4mpi4j7wm46iy5wdieqkestxve4yq"
	us-phoenix-1 = "ocid1.image.oc1.phx.aaaaaaaa56l3m7ak64ohd3cjm7krvrc76bvin665xtyh5c56kzcxbajcfxxq"
    }
}
*/


# Compute Instance counts
# Bastion server count.  1 should be enough
variable "BastionNodeCount" { default = "1" }
variable "BastionNodeShape" { default = "VM.Standard2.1" }



variable "ibm_ss_version" { default = "5.0.5.0" }

# Should be a http/https link which is accessible from the compute instances we will create. You can use OCI Object Storage bucket with pre-authenticated URL.  
##variable "software_download_url" { default = "http://somehost.com" }
# example: https://objectstorage.us-phoenix-1.oraclecloud.com/p/B_xxxxxx-xxxxxx/n/tenancyname/b/bucketname/o/Scale_dme_install-5.0.2.0_x86_64.tar
variable "software_download_url" { default = "https://objectstorage.us-ashburn-1.oraclecloud.com/p/rSQqAwpkpDjytxPGwW_Y1QPPKLyMGkC6EeF4djQr_L2vEdWzEXDlsiplVBceeKxV/n/hpc/b/spectrum_scale/o/Spectrum_Scale_Data_Management-5.0.5.0-x86_64-Linux-install" }
# https://objectstorage.us-ashburn-1.oraclecloud.com/p/bOBlJbTl0cLmRlfXFp05A6hcRKLA-QzIzB0dLP9OEW6yArZdjvvWiBwD64j0JzW_/n/hpc/b/spectrum_scale/o/Spectrum%20Scale%205.0.4.1%20Developer%20Edition.zip



# File System Configurations
variable "BlockSize" { default = "2M" }
variable "DataReplica" { default = "1" }
variable "metadataReplica" { default = "2" }
variable "GpfsMountPoint" { default = "/gpfs/fs1" }
variable "fileSystemName" { default = "fs1" }

# NSD Configurations
# Block Volumes count and size of each disk
variable "SharedData" {
  type = map(string)
  default = {
    Count      = "2"
    Size       = "50"
  }
}


# Client/Compute Node Configurations
variable "ComputeNodeCount" { default = "2" }
variable "ComputeNodeShape" { default = "VM.Standard2.2" }
variable "ComputeNodeHostnamePrefix" { default = "ss-compute-" }


variable "use_existing_vcn" {
  default = "false"
}

variable "vcn_id" {
  default = ""
}

variable "bastion_subnet_id" {
  default = ""
}

variable "private_subnet_id" {
  default = ""
}



##################################################
## Variables which should not be changed by user
##################################################

locals {
  bastion_subnet_id = var.use_existing_vcn ? var.bastion_subnet_id : element(concat(oci_core_subnet.public.*.id, [""]), 0)
  private_subnet_id = var.use_existing_vcn ? var.private_subnet_id : element(concat(oci_core_subnet.private.*.id, [""]), 0)
  private_subnet_domain_name= ("${data.oci_core_subnet.private.dns_label}.${data.oci_core_vcn.vcn.dns_label}.oraclevcn.com" )
  vcn_domain_name=("${data.oci_core_vcn.vcn.dns_label}.oraclevcn.com" )
}


variable "SharedDataVolumeAttachDeviceMapping" {
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


variable "scripts_directory" { default = "../direct_attached_scripts" }
variable "installer_node" { default = "1" }


