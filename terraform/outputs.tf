



output "SSH login " {
value = <<END
        Bastion: ssh -i ~/.ssh/id_rsa ${var.ssh_user}@${oci_core_instance.bastion.*.public_ip[0]}
        Node-1: ssh -i ~/.ssh/id_rsa ${var.ssh_user}@${oci_core_instance.ibmss_1.*.public_ip[0]}
        Node-2: ssh -i ~/.ssh/id_rsa ${var.ssh_user}@${oci_core_instance.ibmss_2.*.public_ip[0]}
        Node-3: ssh -i ~/.ssh/id_rsa ${var.ssh_user}@${oci_core_instance.ibmss_3.*.public_ip[0]}
        IBM Client: ssh -i ~/.ssh/id_rsa ${var.ssh_user}@${oci_core_instance.ibmss_client.*.public_ip[0]}



END
}





