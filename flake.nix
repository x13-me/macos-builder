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
          gnumake
          llvmPackages.clang-unwrapped
          lld
          llvm
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
          ninja
        ];
    in
    {
      packages = forAllSystems (pkgs:
        let
          # OpenSSL is split in nixpkgs: headers in dev, libraries in out, binaries in bin.
          # Root-prep steps compile/link against a single prefix, so expose a merged one.
          opensslPrefix = pkgs.symlinkJoin {
            name = "openssl-prefix";
            paths = [ pkgs.openssl.out pkgs.openssl.dev pkgs.openssl.bin ];
          };
        in
        {
          ci-tools = pkgs.buildEnv {
            name = "unixnu-macos-builder-ci-tools";
            paths = ciToolList pkgs;
          };
          openssl = opensslPrefix;
          default = self.packages.${pkgs.stdenv.hostPlatform.system}.ci-tools;
        });

      devShells = forAllSystems (pkgs:
        let
          opensslPrefix = pkgs.symlinkJoin {
            name = "openssl-prefix";
            paths = [ pkgs.openssl.out pkgs.openssl.dev pkgs.openssl.bin ];
          };
        in
        {
          default = pkgs.mkShellNoCC {
            packages = ciToolList pkgs;
            shellHook = ''
              export OPENSSL_PREFIX="${opensslPrefix}"
            '';
          };
          ci = self.devShells.${pkgs.stdenv.hostPlatform.system}.default;
        });
    };
}
