{
    description = "Dev flake";

    inputs = {
        nixpkgs.url = "nixpkgs/nixos-unstable";
        flake-utils.url = "github:numtide/flake-utils";
    };

    outputs = { self, nixpkgs, flake-utils }:
        flake-utils.lib.eachDefaultSystem (system:
            let
                pkgs = import nixpkgs { inherit system; };
            in {
                # Define devShell with aliases
                devShell = pkgs.mkShell {
                    name = "dev-shell";
                    buildInputs = with pkgs; [
                        npins
                        nixos-anywhere
                        nixos-rebuild
                        nil
                        jq
                    ];

                    shellHook = ''
                        export NIX_PATH="nixpkgs=${nixpkgs}:nixos-config=$PWD/configuration.nix"
                    '';
                };
        });
}
