

output "SSH-login" {
value = <<END

        Bastion: ssh -i ${var.ssh_private_key_path} ${var.ssh_user}@${oci_core_instance.bastion.*.public_ip[0]}

        Server1: ssh -i ${var.ssh_private_key_path}  -o BatchMode=yes -o StrictHostkeyChecking=no  -o ProxyCommand="ssh -i ${var.ssh_private_key_path} -o BatchMode=yes -o StrictHostkeyChecking=no ${var.ssh_user}@${element(concat(oci_core_instance.bastion.*.public_ip, [""]), 0)} -W %h:%p %r" ${var.ssh_user}@${element(concat(oci_core_instance.nsd_node.*.private_ip, [""]), 0)}


        Server2: ssh -i ${var.ssh_private_key_path}  -o BatchMode=yes -o StrictHostkeyChecking=no  -o ProxyCommand="ssh -i ${var.ssh_private_key_path} -o BatchMode=yes -o StrictHostkeyChecking=no ${var.ssh_user}@${element(concat(oci_core_instance.bastion.*.public_ip, [""]), 0)} -W %h:%p %r" ${var.ssh_user}@${element(concat(oci_core_instance.nsd_node.*.private_ip, [""]), 1)}

        Client-1: ssh -i ${var.ssh_private_key_path}  -o BatchMode=yes -o StrictHostkeyChecking=no  -o ProxyCommand="ssh -i ${var.ssh_private_key_path} -o BatchMode=yes -o StrictHostkeyChecking=no ${var.ssh_user}@${element(concat(oci_core_instance.bastion.*.public_ip, [""]), 0)} -W %h:%p %r" ${var.ssh_user}@${element(concat(oci_core_instance.client_node.*.private_ip, [""]), 0)}

        MGMT-1: ssh -i ${var.ssh_private_key_path}  -o BatchMode=yes -o StrictHostkeyChecking=no  -o ProxyCommand="ssh -i ${var.ssh_private_key_path} -o BatchMode=yes -o StrictHostkeyChecking=no ${var.ssh_user}@${element(concat(oci_core_instance.bastion.*.public_ip, [""]), 0)} -W %h:%p %r" ${var.ssh_user}@${element(concat(oci_core_instance.mgmt_gui_node.*.private_ip, [""]), 0)}

        CES-1: ssh -i ${var.ssh_private_key_path}  -o BatchMode=yes -o StrictHostkeyChecking=no  -o ProxyCommand="ssh -i ${var.ssh_private_key_path} -o BatchMode=yes -o StrictHostkeyChecking=no ${var.ssh_user}@${element(concat(oci_core_instance.bastion.*.public_ip, [""]), 0)} -W %h:%p %r" ${var.ssh_user}@${element(concat(oci_core_instance.ces_node.*.private_ip, [""]), 0)}

        nfs_client-1: ssh -i ${var.ssh_private_key_path}  -o BatchMode=yes -o StrictHostkeyChecking=no  -o ProxyCommand="ssh -i ${var.ssh_private_key_path} -o BatchMode=yes -o StrictHostkeyChecking=no ${var.ssh_user}@${element(concat(oci_core_instance.bastion.*.public_ip, [""]), 0)} -W %h:%p %r" ${var.ssh_user}@${element(concat(oci_core_instance.bastion.*.private_ip, [""]), 0)}

        windows_smb_client-1: ssh -i ${var.ssh_private_key_path}  -o BatchMode=yes -o StrictHostkeyChecking=no  -o ProxyCommand="ssh -i ${var.ssh_private_key_path} -o BatchMode=yes -o StrictHostkeyChecking=no ${var.ssh_user}@${element(concat(oci_core_instance.bastion.*.public_ip, [""]), 0)} -W %h:%p %r" ${var.ssh_user}@${element(concat(oci_core_instance.windows_smb_client.*.private_ip, [""]), 0)}

END
}


output "Full-list-of-Servers" {
value = <<END

        Bastion: ${join(",", oci_core_instance.bastion.*.public_ip)}
        NSD-Node: ${join(",", oci_core_instance.nsd_node.*.private_ip)}
        Compute-Node: ${join(",", oci_core_instance.client_node.*.private_ip)}
        MGMT-GUI: ${join(",", oci_core_instance.mgmt_gui_node.*.private_ip)}
        CES: ${join(",", oci_core_instance.ces_node.*.private_ip)}
        Windows-SMB-Client: ${join(",", oci_core_instance.windows_smb_client.*.private_ip)}

END
}
