terraform {
  required_providers {
    hcloud = {
      source  = "hetznercloud/hcloud"
      version = "~> 1.51"
    }
  }
}

provider "hcloud" {
  token = var.hcloud_token
}

# Check if the SSH key is provided, if not create it
resource "tls_private_key" "nix_key" {
  algorithm = "ED25519"
}


resource "hcloud_ssh_key" "nix_key" {
  name       = var.ssh_key_name
  public_key = var.pub_ssh_key != null ? var.pub_ssh_key : tls_private_key.nix_key.public_key_openssh
}

resource "hcloud_server" "nix_server" {
  name        = var.server_name
  server_type = var.server_type
  location    = var.location
  image       = "ubuntu-24.04"
  ssh_keys = [hcloud_ssh_key.nix_key.id]
}

module "deploy" {
  source = "github.com/nix-community/nixos-anywhere//terraform/all-in-one"
  nixos_system_attr      = "./flake#nixosConfigurations.hetzner-cloud.config.system.build.toplevel"
  nixos_partitioner_attr = "./flake#nixosConfigurations.hetzner-cloud.config.system.build.diskoScript"

  target_host = hcloud_server.nix_server.ipv4_address
  instance_id = hcloud_server.nix_server.id
  extra_files_script = "${path.module}/extra_files_script.sh"

  install_ssh_key = var.priv_ssh_key != null ? var.priv_ssh_key : tls_private_key.nix_key.private_key_openssh
  deployment_ssh_key = var.priv_ssh_key != null ? var.priv_ssh_key : tls_private_key.nix_key.private_key_openssh
  special_args = {
    extraPublicKeys = var.pub_ssh_key != null ? [var.pub_ssh_key] : [tls_private_key.nix_key.public_key_openssh]
  }
}

resource "null_resource" "copy_files" {
  depends_on = [hcloud_server.nix_server]

  connection {
    type        = "ssh"
    host        = hcloud_server.nix_server.ipv4_address
    user        = "root"
    private_key = var.priv_ssh_key != null ? var.priv_ssh_key : tls_private_key.nix_key.private_key_openssh
  }

  provisioner "remote-exec" {
    inline = [
      "mkdir -p /etc/nixos"
    ]
  }

  provisioner "file" {
    source      = "${path.module}/flake/"
    destination = "/etc/nixos"
  }
}