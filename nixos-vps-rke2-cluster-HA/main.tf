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

// Create load balancer for the RKE2 cluster in preparation for high availability
resource "hcloud_load_balancer" "rke2_lb" {
  count              = var.extra_server_count > 0 ? 1 : 0
  name               = "${var.cluster_name}-lb"
  load_balancer_type = var.lb_type
  location           = var.location
  algorithm {
    type = "round_robin"
  }
  labels = {
    role = "rke2-lb"
  }
}

// Create K8S API, Register HTTP and HTTPS services on the load balancer
resource "hcloud_load_balancer_service" "rke2_lb_api" {
  count            = var.extra_server_count > 0 ? 1 : 0
  load_balancer_id = hcloud_load_balancer.rke2_lb[0].id
  protocol         = "tcp"
  listen_port      = 6443
  destination_port = 6443
}

resource "hcloud_load_balancer_service" "rke2_lb_supervisor_api" {
  count            = var.extra_server_count > 0 ? 1 : 0
  load_balancer_id = hcloud_load_balancer.rke2_lb[0].id
  protocol         = "tcp"
  listen_port      = 9345
  destination_port = 9345
}

resource "hcloud_load_balancer_service" "rke2_lb_http" {
  count            = var.extra_server_count > 0 ? 1 : 0
  load_balancer_id = hcloud_load_balancer.rke2_lb[0].id
  protocol         = "tcp"
  listen_port      = 80
  destination_port = 80
}

resource "hcloud_load_balancer_service" "rke2_lb_https" {
  count            = var.extra_server_count > 0 ? 1 : 0
  load_balancer_id = hcloud_load_balancer.rke2_lb[0].id
  protocol         = "tcp"
  listen_port      = 443
  destination_port = 443
}

// Create placement group for the RKE2 cluster servers/agents
resource "hcloud_placement_group" "rke2_placement_group" {
  name = "${var.cluster_name}-placement-group"
  type = "spread"

  labels = {
    role = "rke2-placement-group"
  }
}


resource "hcloud_server" "rke2_server" {
  name        = "${var.cluster_name}-server-1"
  server_type = var.server_type
  location    = var.location
  image       = "ubuntu-24.04"
  ssh_keys = [hcloud_ssh_key.nix_key.id]
  placement_group_id = hcloud_placement_group.rke2_placement_group.id
}

module "deploy_server" {
  source                 = "github.com/nix-community/nixos-anywhere//terraform/all-in-one"
  nixos_system_attr      = "./flake#nixosConfigurations.hetzner-cloud.config.system.build.toplevel"
  nixos_partitioner_attr = "./flake#nixosConfigurations.hetzner-cloud.config.system.build.diskoScript"

  target_host        = hcloud_server.rke2_server.ipv4_address
  instance_id        = hcloud_server.rke2_server.id
  extra_files_script = "${path.module}/extra_files_script.sh"

  install_ssh_key    = var.priv_ssh_key != null ? var.priv_ssh_key : tls_private_key.nix_key.private_key_openssh
  deployment_ssh_key = var.priv_ssh_key != null ? var.priv_ssh_key : tls_private_key.nix_key.private_key_openssh
  special_args = {
    extraPublicKeys = var.pub_ssh_key != null ? [var.pub_ssh_key] : [tls_private_key.nix_key.public_key_openssh]
    rke2Role        = "server"
    hostname        = hcloud_server.rke2_server.name
    tlsSans         = var.extra_server_count > 0 ? [hcloud_load_balancer.rke2_lb[0].ipv4] : []
    rke2Server = null
  }
}

// Add main server to the load balancer
resource "hcloud_load_balancer_target" "rke2_lb_server" {
  count            = var.extra_server_count > 0 ? 1 : 0
  load_balancer_id = hcloud_load_balancer.rke2_lb[0].id
  type             = "server"
  server_id        = hcloud_server.rke2_server.id
  use_private_ip   = false
}

resource "null_resource" "copy_files" {
  depends_on = [hcloud_server.rke2_server, module.deploy_server]
  triggers = {
    out = module.deploy_server.result.out # Run everytime the flake changes to update/persist the files
  }

  connection {
    type        = "ssh"
    host        = hcloud_server.rke2_server.ipv4_address
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
    destination = "/root/flake"
  }

  provisioner "file" {
    source      = "${path.module}/extra_files_script.sh"
    destination = "/root/extra_files_script.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x /root/extra_files_script.sh",
      "cd /",
      "/root/extra_files_script.sh"
    ]
  }
}

resource "null_resource" "fetch_rke2_token" {
  depends_on = [hcloud_server.rke2_server]

  triggers = {
    always_run = timestamp()
  }

  provisioner "local-exec" {
    command = <<EOT
      set -e
      KEY_FILE=$(mktemp)
      printf "%s" '${var.priv_ssh_key != null ? var.priv_ssh_key : tls_private_key.nix_key.private_key_openssh}' > "$KEY_FILE"
      chmod 600 "$KEY_FILE"
      REMOTE_TOKEN_FILE="/tmp/rke2_token_$$"
      SERVER_IP="${hcloud_server.rke2_server.ipv4_address}"

      # Retry for up to 10 minutes (600 seconds)
      timeout=600
      interval=5
      start_time=$(date +%s)
      while true; do
        if ssh -i "$KEY_FILE" -o StrictHostKeyChecking=no -o ConnectTimeout=5 root@$SERVER_IP "test -f /var/lib/rancher/rke2/server/token"; then
          break
        fi
        now=$(date +%s)
        if [ $((now - start_time)) -ge $timeout ]; then
          echo "Timeout waiting for server token file"
          exit 1
        fi
        sleep $interval
      done

      ssh -i "$KEY_FILE" -o StrictHostKeyChecking=no root@$SERVER_IP "cat /var/lib/rancher/rke2/server/token > $REMOTE_TOKEN_FILE"
      scp -i "$KEY_FILE" -o StrictHostKeyChecking=no root@$SERVER_IP:$REMOTE_TOKEN_FILE ./rke2_token
      ssh -i "$KEY_FILE" -o StrictHostKeyChecking=no root@$SERVER_IP "rm -f $REMOTE_TOKEN_FILE"
      rm -f "$KEY_FILE"
    EOT
    interpreter = ["bash", "-c"]
  }
}

data "external" "node_token" {
  depends_on = [null_resource.fetch_rke2_token]
  program = [
    "bash", "-c", "if [ -s ./rke2_token ]; then cat ./rke2_token | jq -R '{token: .}'; else echo '{\"token\":\"\"}'; fi"
  ]
}


//Create additional servers for high availability
resource "hcloud_server" "rke2_extra_servers" {
  count       = var.extra_server_count
  name        = "${var.cluster_name}-server-${count.index + 2}"
  server_type = var.server_type
  location    = var.location
  image       = "ubuntu-24.04"
  ssh_keys = [hcloud_ssh_key.nix_key.id]
  placement_group_id = hcloud_placement_group.rke2_placement_group.id
}

module "deploy_extra_servers" {
  source                 = "github.com/nix-community/nixos-anywhere//terraform/all-in-one"
  nixos_system_attr      = "./flake#nixosConfigurations.hetzner-cloud.config.system.build.toplevel"
  nixos_partitioner_attr = "./flake#nixosConfigurations.hetzner-cloud.config.system.build.diskoScript"

  count              = var.extra_server_count
  target_host        = hcloud_server.rke2_extra_servers[count.index].ipv4_address
  instance_id        = hcloud_server.rke2_extra_servers[count.index].id
  extra_files_script = "${path.module}/extra_files_script.sh"

  install_ssh_key    = var.priv_ssh_key != null ? var.priv_ssh_key : tls_private_key.nix_key.private_key_openssh
  deployment_ssh_key = var.priv_ssh_key != null ? var.priv_ssh_key : tls_private_key.nix_key.private_key_openssh
  special_args = {
    extraPublicKeys = var.pub_ssh_key != null ? [var.pub_ssh_key] : [tls_private_key.nix_key.public_key_openssh]
    rke2Role        = "server"
    rke2Server      = var.extra_server_count > 0 ? hcloud_load_balancer.rke2_lb[0].ipv4 : hcloud_server.rke2_server.ipv4_address
    rke2Token       = data.external.node_token.result.token
    hostname        = "${var.cluster_name}-server-${count.index + 2}"
    tlsSans = [hcloud_load_balancer.rke2_lb[0].ipv4]
  }
}

resource "null_resource" "copy_files_extra_servers" {
  count = var.extra_server_count
  depends_on = [hcloud_server.rke2_extra_servers, module.deploy_extra_servers]

  # Each agent's deploy result should trigger a copy
  triggers = {
    # Use the agent index to access the specific module instance
    extra_server_id = hcloud_server.rke2_extra_servers[count.index].id
  }

  connection {
    type        = "ssh"
    host        = hcloud_server.rke2_extra_servers[count.index].ipv4_address
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
    destination = "/root/flake"
  }

  provisioner "file" {
    source      = "${path.module}/extra_files_script.sh"
    destination = "/root/extra_files_script.sh"
  }

  # Add execution of the extra_files_script.sh like we do for the server
  provisioner "remote-exec" {
    inline = [
      "chmod +x /root/extra_files_script.sh",
      "cd /",
      "/root/extra_files_script.sh"
    ]
  }
}

// Add extra servers to the load balancer
resource "hcloud_load_balancer_target" "rke2_lb_extra_servers" {
  count            = var.extra_server_count
  load_balancer_id = hcloud_load_balancer.rke2_lb[0].id
  type             = "server"
  server_id        = hcloud_server.rke2_extra_servers[count.index].id
  use_private_ip   = false
}

// Create agents for the RKE2 cluster
resource "hcloud_server" "rke2_agent" {
  count       = var.agent_count
  name        = "${var.cluster_name}-agent-${count.index + 1}"
  server_type = var.agent_type
  location    = var.location
  image       = "ubuntu-24.04"
  ssh_keys = [hcloud_ssh_key.nix_key.id]
  placement_group_id = hcloud_placement_group.rke2_placement_group.id
  labels = {
    role = "rke2-agent"
  }
}

module "deploy_agent" {
  source                 = "github.com/nix-community/nixos-anywhere//terraform/all-in-one"
  nixos_system_attr      = "./flake#nixosConfigurations.hetzner-cloud.config.system.build.toplevel"
  nixos_partitioner_attr = "./flake#nixosConfigurations.hetzner-cloud.config.system.build.diskoScript"

  count              = var.agent_count
  target_host        = hcloud_server.rke2_agent[count.index].ipv4_address
  instance_id        = hcloud_server.rke2_agent[count.index].id
  extra_files_script = "${path.module}/extra_files_script.sh"

  install_ssh_key    = var.priv_ssh_key != null ? var.priv_ssh_key : tls_private_key.nix_key.private_key_openssh
  deployment_ssh_key = var.priv_ssh_key != null ? var.priv_ssh_key : tls_private_key.nix_key.private_key_openssh
  special_args = {
    extraPublicKeys = var.pub_ssh_key != null ? [var.pub_ssh_key] : [tls_private_key.nix_key.public_key_openssh]
    rke2Role        = "agent"
    rke2Server      = var.extra_server_count > 0 ? hcloud_load_balancer.rke2_lb[0].ipv4 : hcloud_server.rke2_server.ipv4_address
    rke2Token       = data.external.node_token.result.token
    hostname        = "${var.cluster_name}-agent-${count.index + 1}"
  }
}

resource "null_resource" "copy_files_agent" {
  count = var.agent_count
  depends_on = [hcloud_server.rke2_agent, module.deploy_agent]

  # Each agent's deploy result should trigger a copy
  triggers = {
    # Use the agent index to access the specific module instance
    agent_id = hcloud_server.rke2_agent[count.index].id
  }

  connection {
    type        = "ssh"
    host        = hcloud_server.rke2_agent[count.index].ipv4_address
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
    destination = "/root/flake"
  }

  provisioner "file" {
    source      = "${path.module}/extra_files_script.sh"
    destination = "/root/extra_files_script.sh"
  }

  # Add execution of the extra_files_script.sh like we do for the server
  provisioner "remote-exec" {
    inline = [
      "chmod +x /root/extra_files_script.sh",
      "cd /",
      "/root/extra_files_script.sh"
    ]
  }
}