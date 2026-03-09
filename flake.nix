{
  description = "Time Invoice - CLI tool for generating invoices from timewatcher JSON";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        beamPackages = pkgs.beam.packages.erlang_27;

        deps = import ./deps.nix {
          lib = pkgs.lib;
          inherit beamPackages;
        };
      in {
        packages.default = beamPackages.mixRelease {
          pname = "time_invoice";
          version = "0.1.0";
          src = ./.;
          mixNixDeps = deps;

          mixEnv = "prod";
        };

        devShells.default = pkgs.mkShell {
          buildInputs = [
            beamPackages.elixir
            beamPackages.erlang
            pkgs.mix2nix
          ];
        };
      });
}
