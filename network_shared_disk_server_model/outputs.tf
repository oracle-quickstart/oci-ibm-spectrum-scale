

output "SSH-login" {
value = <<END

        Bastion: ssh -i $CHANGEME ${var.ssh_user}@${oci_core_instance.bastion.*.public_ip[0]}

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
