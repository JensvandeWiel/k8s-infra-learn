# K8S Infra learn
This repo contains my journey of lerning to deploy kubernetes using declerative tools like OpenTofu/Terraform and Nix(OS)
# Why?
I want to easily deploy kubernetes clusters. This repo contains the absolute base, and also contains non-kubernetes related stuff.
### `nixos-vps`
In this directory you'll find a terraform module that deploys a NixOS VPS to Hetzner.
### `nixos-vps-rke2`
In this directory you'll find a terraform module that deploys a NixOS VPS to Hetzner with RKE2 installed with Cilium as CNI.
### `nixos-vps-rke2-cluster`
In this directory you'll find a terraform module that deploys a rke2 cluster to Hetzner with Cilium as CNI using NixOS as the OS.

# This is a learning project
This is a learning project where i learn the following:
- NixOS
- OpenTofu/Terraform
- Kubernetes
- RKE2
- Network related stuff
- Linux in depth
## Help me improve!
If you have any suggestions or improvements, feel free to open an issue or a pull request. I'm always looking for ways to improve my code and learn new things. If you do so please explain what you did and why you did it, as this will help me learn and understand the changes better.