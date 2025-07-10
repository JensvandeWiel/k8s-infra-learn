{
  modulesPath,
  lib,
  pkgs,
  ...
} @ args:
{
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
    (modulesPath + "/profiles/qemu-guest.nix")
    ./disk-config.nix
  ];
  boot.kernelModules = [
    "iptable_mangle"
    "iptable_filter"
    "iptable_nat"
    "iptable_raw"
    "xt_socket"
    "ip_tables"
    "ip6_tables"
    "x_tables"
    "br_netfilter"
    "overlay"
    "nf_conntrack"
    "nf_nat"
    "nf_defrag_ipv4"
    "nf_defrag_ipv6"
    "veth"
    "bpfilter"
    "cls_bpf"
    "act_bpf"
    "sch_clsact"
  ];
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  boot.loader.grub = {
    # no need to set devices, disko will add all devices that have a EF02 partition to the list already
    # devices = [ ];
    efiSupport = true;
    efiInstallAsRemovable = true;
  };
  services.openssh.enable = true;

  environment.systemPackages = map lib.lowPrio [
    pkgs.curl
    pkgs.gitMinimal
    pkgs.kubectl
    pkgs.cilium-cli
  ];

  users.users.root.openssh.authorizedKeys.keys = args.extraPublicKeys or [];

  #RKE2
  # Don't interfere with k8s
  networking.firewall.enable = lib.mkForce false;

  services.numtide-rke2 = {
    enable = true;
    role = "server";
    settings = {
      write-kubeconfig-mode = "0644";
      # Specify the external IP/hostname for the API server if needed
      # tls-san = ["your-server-ip-or-hostname"];
      cni = "cilium";
    };
  };


  # Set default KUBECONFIG environment variable for all users
  environment.variables.KUBECONFIG = "/etc/rancher/rke2/rke2.yaml";

  system.stateVersion = "24.05";
}
