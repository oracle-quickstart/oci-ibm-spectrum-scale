

output "SSH_login" {
value = <<END

        Bastion: ssh -i ${var.ssh_private_key_path} ${var.ssh_user}@${oci_core_instance.bastion.*.public_ip[0]}


       ssh -i ${var.ssh_private_key_path}  -o BatchMode=yes -o StrictHostkeyChecking=no  -o ProxyCommand="ssh -i ${var.ssh_private_key_path}  -o BatchMode=yes -o StrictHostkeyChecking=no ${var.ssh_user}@${oci_core_instance.bastion.*.public_ip[0]} -W %h:%p %r" ${var.ssh_user}@${oci_core_instance.ComputeNode.*.private_ip[0]}


       ssh -i ${var.ssh_private_key_path}  -o BatchMode=yes -o StrictHostkeyChecking=no  -o ProxyCommand="ssh -i ${var.ssh_private_key_path}  -o BatchMode=yes -o StrictHostkeyChecking=no ${var.ssh_user}@${oci_core_instance.bastion.*.public_ip[0]} -W %h:%p %r" ${var.ssh_user}@${oci_core_instance.ComputeNode.*.private_ip[1]}


END
}


