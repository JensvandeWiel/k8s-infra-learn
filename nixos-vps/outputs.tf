output "public_ip" {
  value = hcloud_server.nix_server.ipv4_address
}

output "public_ssh_key" {
  value = var.pub_ssh_key != null ? var.pub_ssh_key : tls_private_key.nix_key.public_key_openssh
}

output "private_ssh_key" {
  sensitive = true
  value = var.priv_ssh_key != null ? var.priv_ssh_key : tls_private_key.nix_key.private_key_pem
}
