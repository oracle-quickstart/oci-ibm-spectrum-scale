/*
Resource to IOR.
*/
resource "null_resource" "ior-setup" {
  depends_on = [
    oci_core_instance.client_node
   ]
  count = 1
  triggers = {
    instance_ids = join(",", oci_core_instance.client_node.*.id)
  }

  provisioner "file" {
    source      = "scripts/ior_install.sh"
    destination = "/tmp/ior_install.sh"
    connection {
      agent               = false
      timeout             = "30m"
      host                = element(oci_core_instance.client_node.*.private_ip, count.index)
      user                = var.ssh_user
      private_key         = tls_private_key.ssh.private_key_pem
      bastion_host        = oci_core_instance.bastion[0].public_ip
      bastion_port        = "22"
      bastion_user        = var.ssh_user
      bastion_private_key = tls_private_key.ssh.private_key_pem
    }
  }

  provisioner "remote-exec" {
    connection {
      agent               = false
      timeout             = "30m"
      host                = element(oci_core_instance.client_node.*.private_ip, count.index)
      user                = var.ssh_user
      private_key         = tls_private_key.ssh.private_key_pem
      bastion_host        = oci_core_instance.bastion[0].public_ip
      bastion_port        = "22"
      bastion_user        = var.ssh_user
      bastion_private_key = tls_private_key.ssh.private_key_pem
    }
    inline = [
      "set -x",
      "sudo -s bash -c 'set -x && chmod 777 /tmp/*.sh'",
      "sudo -s bash -c 'set -x && /tmp/ior_install.sh ${var.spectrum_scale["gpfs_mount_point"]} ${var.client_node["node_count"]} ${var.client_node["hostname_prefix"]} ${oci_core_virtual_network.gpfs.dns_label} '",
    ]
  }
}

