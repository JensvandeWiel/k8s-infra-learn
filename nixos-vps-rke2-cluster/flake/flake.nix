{
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
  inputs.disko.url = "github:nix-community/disko";
  inputs.disko.inputs.nixpkgs.follows = "nixpkgs";
  inputs.nixos-facter-modules.url = "github:numtide/nixos-facter-modules";
  inputs.rke2.url = "github:numtide/nixos-rke2";

  outputs = { self, nixpkgs, disko, nixos-facter-modules, rke2, ... }:
    {
      nixosConfigurations.hetzner-cloud = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          disko.nixosModules.disko
          rke2.nixosModules.default
          ./configuration.nix
        ];
      };
      # We wont use this since we will not use digitalocean
      nixosConfigurations.digitalocean = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          ./digitalocean.nix
          disko.nixosModules.disko
          rke2.nixosModules.default
          { disko.devices.disk.disk1.device = "/dev/vda"; }
          ./configuration.nix
        ];
      };
      nixosConfigurations.hetzner-cloud-aarch64 = nixpkgs.lib.nixosSystem {
        system = "aarch64-linux";
        modules = [
          disko.nixosModules.disko
          rke2.nixosModules.default
          ./configuration.nix
        ];
      };

      # Use this for all other targets
      # nixos-anywhere --flake .#generic --generate-hardware-config nixos-generate-config ./hardware-configuration.nix <hostname>
      nixosConfigurations.generic = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          disko.nixosModules.disko
          rke2.nixosModules.default
          ./configuration.nix
          ./hardware-configuration.nix
        ];
      };

      # Slightly experimental: Like generic, but with nixos-facter (https://github.com/numtide/nixos-facter)
      # nixos-anywhere --flake .#generic-nixos-facter --generate-hardware-config nixos-facter facter.json <hostname>
      nixosConfigurations.generic-nixos-facter = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          disko.nixosModules.disko
          rke2.nixosModules.default
          ./configuration.nix
          nixos-facter-modules.nixosModules.facter
          {
            config.facter.reportPath =
              if builtins.pathExists ./facter.json then
                ./facter.json
              else
                throw "Have you forgotten to run nixos-anywhere with `--generate-hardware-config nixos-facter ./facter.json`?";
          }
        ];
      };
    };
}