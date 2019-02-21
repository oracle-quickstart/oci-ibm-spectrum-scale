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

variable "VPC-CIDR" { default = "10.0.0.0/16" }


variable "InstanceImageOCID" {
    type = "map"
    default = {
        // See https://docs.us-phoenix-1.oraclecloud.com/images/ or https://docs.cloud.oracle.com/iaas/images/
        // Oracle-provided image "CentOS-7-2018.08.15-0"
	eu-frankfurt-1 = "ocid1.image.oc1.eu-frankfurt-1.aaaaaaaatz6zixwltzswnmzi2qxdjcab6nw47xne4tco34kn6hltzdppmada" 
	us-ashburn-1 = "ocid1.image.oc1.iad.aaaaaaaah6ui3hcaq7d43esyrfmyqb3mwuzn4uoxjlbbdwoiicdmntlvwpda"
	uk-london-1 = "ocid1.image.oc1.uk-london-1.aaaaaaaai3czrt22cbu5uytpci55rcy4mpi4j7wm46iy5wdieqkestxve4yq"
	us-phoenix-1 = "ocid1.image.oc1.phx.aaaaaaaarbacra7juwrie5idcadtgbj3llxcu7p26rj4t3xujyqwwopy2wva"
    }
}


# Compute Instance counts
# Bastion server count.  1 should be enough
variable "bastion_server_count" { default = "1" }
variable "ibmss_2_count" { default = "1" }
variable "ibmss_1_count" { default = "1" }
variable "ibmss_3_count" { default = "1" }
variable "ibmss_client_count" { default = "1" }


# instance shapes
variable "bastion_server_shape" { default = "VM.Standard2.1" }
variable "ibmss_2_server_shape" { default = "VM.Standard2.1" }
variable "ibmss_1_server_shape" { default = "VM.Standard2.1" }
variable "ibmss_3_shape" { default = "VM.Standard2.1" }
variable "ibmss_client_shape" { default = "VM.Standard2.1" }


# size in GiB for tableau data on all nodes.  1 block storage volume per node.
variable "data_volume_size" { default = "1024" }


variable "instance_shape" {
  default = "VM.Standard2.1"
}

