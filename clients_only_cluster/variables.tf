###
## Variables.tf for Terraform
## Defines variables and local values
###

variable "vpc_cidr" { default = "172.16.0.0/16" }


# One bastion node is enough
variable "bastion" {
  type = map(string)
    default = {
      shape      = "VM.Standard2.2"
      node_count = 1
      hostname_prefix = "bastion1-"
    }
}




# Client nodes variables. Min node required is 3 to have quorum.  For production, with some customization, less than 3 nodes can be supported. 
variable "client_node" {
  type = map(string)
    default = {
      shape      = "VM.Standard2.4"
      #shape      = "BM.Standard.E2.64"
      node_count = 3
      hostname_prefix = "ss-compute-"
    }
}


variable "use_existing_vcn" {
  default = "false"
}

variable "vcn_id" {
  default = ""
}

variable "bastion_subnet_id" {
  default = ""
}

# If Spectrum Scale servers are Baremetal nodes, then this should be the "Private-FS-Subnet" subnet OCID.  If Spectrum Scale servers are VMs or BM.HPC2.36, then this should be the "Private-SpectrumScale" subnet OCID.
variable "fs_subnet_id" {
  default = ""
}



/*
  Spectrum Scale related variables
*/
/*
  download_url : Should be a http/https link which is accessible from the compute instances we will create. You can use OCI Object Storage bucket with pre-authenticated URL.  example: https://objectstorage.us-ashburn-1.oraclecloud.com/p/DLdr-xxxxxxxxxxxxxxxxxxxx/n/hpc/b/spectrum_scale/o/Spectrum_Scale_Data_Management-5.0.3.2-x86_64-Linux-install
*/
variable "spectrum_scale" {
  type = map(string)
    default = {
      "version"      = "5.0.4.1"
      "download_url" = "https://objectstorage.us-ashburn-1.oraclecloud.com/p/IIPwjm0Xktrw4ZN-y1pkwHhzEdGRNwi8lSWj_iYiSWl58GPQrm9pNOu5z3wcpI7F/n/hpc_limited_availability/b/spectrum_scale/o/Spectrum%20Scale%205.0.4.1%20Developer%20Edition.zip"
      high_availability = false
    }
}


# if high_availability is set to false, then first AD value from the below list will be used to create cluster.
# if high_availability is set to true, then both values from the below list will be used to create cluster.
variable "availability_domain" { default = [1,2] }
#variable "availability_domain" { default = [2,3] }
#variable "availability_domain" { default = [3,1] }






locals {
  site1 = (var.spectrum_scale["high_availability"] ? var.availability_domain[0] - 1 : var.availability_domain[0] - 1)
  site2 = (var.spectrum_scale["high_availability"] ? var.availability_domain[1] - 1 : var.availability_domain[0] - 1)
  dual_nics = (length(regexall("^BM", var.client_node["shape"])) > 0 ? true : false)
  bastion_subnet_id = var.use_existing_vcn ? var.bastion_subnet_id : element(concat(oci_core_subnet.public.*.id, [""]), 0)
  fs_subnet_id        = var.use_existing_vcn ? var.fs_subnet_id : element(concat(oci_core_subnet.fs.*.id, [""]), 0)
  client_subnet_id    = local.fs_subnet_id
  filesystem_subnet_domain_name= ("${data.oci_core_subnet.fs_subnet.dns_label}.${data.oci_core_vcn.vcn.dns_label}.oraclevcn.com" )
  vcn_domain_name=("${data.oci_core_vcn.vcn.dns_label}.oraclevcn.com" )

}




##################################################
## Variables which should not be changed by user
##################################################

# Please do not change.  The first nsd node is used for cluster deployment
variable "installer_node" { default = "1" }

variable "scripts_directory" { default = "../clients_only_cluster_scripts" }


###############

variable "tenancy_ocid" {}
variable "user_ocid" {}
variable "fingerprint" {}
variable "private_key_path" {}
#variable "region" { default = "us-ashburn-1" }
variable "region" { default = "uk-london-1" }

variable "compartment_ocid" {}
variable "ssh_public_key" {}
variable "ssh_private_key" {}
variable "ssh_private_key_path" {}

/*
  For instances created using Oracle Linux and CentOS images, the user name opc is created automatically.
  For instances created using the Ubuntu image, the user name ubuntu is created automatically.
  The ubuntu user has sudo privileges and is configured for remote access over the SSH v2 protocol using RSA keys. The SSH public keys that you specify while creating instances are added to the /home/ubuntu/.ssh/authorized_keys file.
  For more details: https://docs.cloud.oracle.com/iaas/Content/Compute/References/images.htm#one
  For Ubuntu images,  set to ubuntu.
  # variable "ssh_user" { default = "ubuntu" }
*/
variable "ssh_user" { default = "opc" }



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
