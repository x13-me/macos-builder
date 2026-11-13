{
  description = "Nix-flake CI environment and scripts for UniXNU macOS-runner target preparation";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs =
    { self, nixpkgs }:
    let
      systems = [
        "aarch64-darwin"
        "x86_64-darwin"
        "aarch64-linux"
        "x86_64-linux"
      ];
      forAllSystems = f: nixpkgs.lib.genAttrs systems (system: f nixpkgs.legacyPackages.${system});
      ciToolList =
        pkgs:
        with pkgs;
        [
          bash
          curl
          dtc
          git
          mtools
          opencode
          openssl
          python3
          qemu
          unifdef
          xz
        ]
        ++ lib.optionals stdenv.hostPlatform.isLinux [
          cmake
          coreutils
          findutils
          gawk
          gnugrep
          gnused
          gnutar
          gzip
          lld
          llvm
          ninja
        ];
    in
    {
      packages = forAllSystems (pkgs: {
        ci-tools = pkgs.buildEnv {
          name = "unixnu-macos-builder-ci-tools";
          paths = ciToolList pkgs;
        };
        openssl = pkgs.openssl;
        default = self.packages.${pkgs.stdenv.hostPlatform.system}.ci-tools;
      });

      devShells = forAllSystems (pkgs: {
        default = pkgs.mkShellNoCC {
          packages = ciToolList pkgs;
          shellHook = ''
            export OPENSSL_PREFIX="${pkgs.openssl.out}"
          '';
        };
        ci = self.devShells.${pkgs.stdenv.hostPlatform.system}.default;
      });
    };
}
