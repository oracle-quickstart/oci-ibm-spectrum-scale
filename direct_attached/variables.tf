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


variable "AD" { default = "2" }

variable "VPC-CIDR" { default = "10.0.0.0/16" }


variable "InstanceImageOCID" {
    type = "map"
    default = {
        // See https://docs.us-phoenix-1.oraclecloud.com/images/ or https://docs.cloud.oracle.com/iaas/images/
        // Oracle-provided image "CentOS-7-2018.08.15-0"
	eu-frankfurt-1 = "ocid1.image.oc1.eu-frankfurt-1.aaaaaaaatz6zixwltzswnmzi2qxdjcab6nw47xne4tco34kn6hltzdppmada" 
	us-ashburn-1 = "ocid1.image.oc1.iad.aaaaaaaaxwo4ovajb6fr5jih6czpffacijuwgwvavhamk5pk5ixkx52yu7da"
	uk-london-1 = "ocid1.image.oc1.uk-london-1.aaaaaaaai3czrt22cbu5uytpci55rcy4mpi4j7wm46iy5wdieqkestxve4yq"
	us-phoenix-1 = "ocid1.image.oc1.phx.aaaaaaaa56l3m7ak64ohd3cjm7krvrc76bvin665xtyh5c56kzcxbajcfxxq"
    }
}


# Compute Instance counts
# Bastion server count.  1 should be enough
variable "BastionNodeCount" { default = "1" }
variable "BastionNodeShape" { default = "VM.Standard2.1" }



variable "ibm_ss_version" { default = "5.0.2.0" }

# Should be a http/https link which is accessible from the compute instances we will create. You can use OCI Object Storage bucket with pre-authenticated URL.  
variable "software_download_url" { default = "http://somehost.com" } 
# example: https://objectstorage.us-phoenix-1.oraclecloud.com/p/B_xxxxxx-xxxxxx/n/tenancyname/b/bucketname/o/Scale_dme_install-5.0.2.0_x86_64.tar

# path to download OCI Command Line Tool to perform multi-attach for Block Volumes
variable "oci_cli_download_url" { default = "http://somehost.com" }


# File System Configurations
variable "BlockSize" { default = "4M" }
variable "DataReplica" { default = "1" }
variable "GpfsMountPoint" { default = "/gpfs/fs1" }
variable "FileSystemName" { default = "fs1" }

# NSD Configurations
# Block Volumes count and size of each disk
variable "SharedData" {
  type = "map"
  default = {
    Count      = "8"
    Size       = "700"
  }
}

variable "SharedMetaData" {
  type = "map"
  default = {
    Count      = "2"
    Size       = "700"
  }
}

# Server Node Configurations
variable "ServerNodeCount" { default = "2" }
variable "ServerNodeShape" { default = "BM.Standard2.52" }  # BM.DenseIO2.52
variable "ServerNodeHostnamePrefix" { default = "ss-server-" }

# Client/Compute Node Configurations
variable "ComputeNodeCount" { default = "2" }
variable "ComputeNodeShape" { default = "BM.DenseIO2.52" }
variable "ComputeNodeHostnamePrefix" { default = "ss-compute-" }

variable "InstallerNode" { default = "1" }

# Callhome Configuration
variable "CompanyName" { default = "Company Name" }
variable "CompanyID"  { default = "1234567" }
variable "CountryCode" { default = "US" }
variable "EmailAddress"  { default = "name@email.com" }


variable "SharedDataVolumeAttachDeviceMapping" {
  type = "map"
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
  }
}

variable "SharedMetaDataVolumeAttachDeviceMapping" {
  type = "map"
  default = {
    "0" = "/dev/oracleoci/oraclevdaa"
    "1" = "/dev/oracleoci/oraclevdab"
    "2" = "/dev/oracleoci/oraclevdac"
    "3" = "/dev/oracleoci/oraclevdad"
    "4" = "/dev/oracleoci/oraclevdae"
    "5" = "/dev/oracleoci/oraclevdaf"
    "6" = "/dev/oracleoci/oraclevdag"
  }
}
