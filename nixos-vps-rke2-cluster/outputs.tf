output "public_ip_server" {
  value       = hcloud_server.rke2_server.ipv4_address
  description = "Public IP address of the RKE2 server node"
}

output "public_ips_agents" {
  value       = hcloud_server.rke2_agent[*].ipv4_address
  description = "Public IP addresses of all RKE2 agent nodes"
}

output "server_token" {
  value       = data.external.node_token.result.token
  sensitive   = true
  description = "RKE2 server token (sensitive)"
}

output "public_ssh_key" {
  value       = var.pub_ssh_key != null ? var.pub_ssh_key : tls_private_key.nix_key.public_key_openssh
  description = "Public SSH key used for the cluster nodes, must align with private_ssh_key"
}

output "private_ssh_key" {
  sensitive   = true
  value       = var.priv_ssh_key != null ? var.priv_ssh_key : tls_private_key.nix_key.private_key_pem
  description = "Private SSH key for accessing the cluster nodes, must align with public_ssh_key"
}
