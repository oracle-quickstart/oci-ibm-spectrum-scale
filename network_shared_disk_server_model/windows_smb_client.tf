variable "cloudinit_ps1" {
  default = "cloudinit.ps1"
}

variable "cloudinit_config" {
  default = "cloudinit.yml"
}

variable "setup_ps1" {
  default = "setup.ps1"
}

variable "userdata" {
  default = "userdata"
}



variable "instance_user" {
  default = "opc"
}

// Copyright (c) 2017, 2019, Oracle and/or its affiliates. All rights reserved.

############
# Cloudinit
############
# Generate a new strong password for your instance
resource "random_string" "instance_password" {
  length  = 16
  special = true
}

# Use the cloudinit.ps1 as a template and pass the instance name, user and password as variables to same
data "template_file" "cloudinit_ps1" {
  vars = {
    instance_user     = "${var.instance_user}"
    instance_password = "${random_string.instance_password.result}"
    instance_name     = "${var.windows_smb_client["hostname_prefix"]}1"
  }

  template = "${file("${var.userdata}/${var.cloudinit_ps1}")}"
}

data "template_cloudinit_config" "cloudinit_config" {
  gzip          = false
  base64_encode = true

  # The cloudinit.ps1 uses the #ps1_sysnative to update the instance password and configure winrm for https traffic
  part {
    filename     = "${var.cloudinit_ps1}"
    content_type = "text/x-shellscript"
    content      = "${data.template_file.cloudinit_ps1.rendered}"
  }

  # The cloudinit.yml uses the #cloud-config to write files remotely into the instance, this is executed as part of instance setup
  part {
    filename     = "${var.cloudinit_config}"
    content_type = "text/cloud-config"
    content      = "${file("${var.userdata}/${var.cloudinit_config}")}"
  }
}

###########
# Compute
###########
resource "oci_core_instance" "windows_smb_client" {
  count = "${var.windows_smb_client["node_count"]}"
  availability_domain = "${lookup(data.oci_identity_availability_domains.ADs.availability_domains[((count.index % 2 == 0) ? local.site1 : local.site2)],"name")}"

  fault_domain        = "FAULT-DOMAIN-${(count.index%3)+1}"
  compartment_id      = "${var.compartment_ocid}"
  display_name        = "${var.windows_smb_client["hostname_prefix"]}${format("%01d", count.index + 1)}"
  hostname_label      = "${var.windows_smb_client["hostname_prefix"]}${format("%01d", count.index + 1)}"

  shape            = "${var.windows_smb_client["shape"]}"
  subnet_id        = "${oci_core_subnet.public.*.id[0]}"


  # Refer cloud-init in https://docs.cloud.oracle.com/iaas/api/#/en/iaas/20160918/datatypes/LaunchInstanceDetails
  metadata = {
    # Base64 encoded YAML based user_data to be passed to cloud-init
    user_data = "${data.template_cloudinit_config.cloudinit_config.rendered}"
  }

  source_details {
    boot_volume_size_in_gbs = "${var.windows_smb_client["boot_volume_size_in_gbs"]}"
    source_id   = "${var.w_images[var.region]}"
    source_type = "image"
  }

}


data "oci_core_instance_credentials" "InstanceCredentials" {
  # depends_on was added as a workaround to TF issue with empty oci_core_instance.windows_smb_client.*.id[0]
  depends_on =  [ oci_core_instance.windows_smb_client ]  
  instance_id = (var.windows_smb_client["node_count"] > 0 ? oci_core_instance.windows_smb_client.*.id[0] : "")
}



##########
# Outputs
##########

output "Username" {
  value = ["${data.oci_core_instance_credentials.InstanceCredentials.username}"]
}

output "Password" {
  value = ["${random_string.instance_password.result}"]
}

output "InstancePublicIP" {
  value = [ (var.windows_smb_client["node_count"] > 0 ? oci_core_instance.windows_smb_client.*.public_ip[0] : "") ]
  # "${oci_core_instance.windows_smb_client.*.public_ip[0]}"]
}

output "InstancePrivateIP" {
  value = [ (var.windows_smb_client["node_count"] > 0 ? oci_core_instance.windows_smb_client.*.private_ip[0] : "") ]
}

