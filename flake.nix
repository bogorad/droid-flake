{
  description = "Runnable Droid CLI launcher for NixOS (x86_64 & aarch64)";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs =
    { self, nixpkgs }:
    let
      supportedSystems = [
        "x86_64-linux"
        "aarch64-linux"
      ];
      forAllSystems = nixpkgs.lib.genAttrs supportedSystems;

      # Map Nix system names to Factory CLI architecture strings
      archMap = {
        "x86_64-linux" = "x64";
        "aarch64-linux" = "arm64";
      };
    in
    {
      # Provide `nix run .` / `nix run github:bogorad/droid-flake`
      apps = forAllSystems (
        system:
        let
          pkgs = import nixpkgs { inherit system; };
          arch = archMap.${system};
        in
        {
          default = {
            type = "app";
            program = "${pkgs.writeShellScript "droid-launcher" ''
              set -euo pipefail

              # Work in a predictable directory (cache within CWD)
              DROID_PATH="./droid"

              # If we already have a droid binary, try to use it
              if [ -x "$DROID_PATH" ]; then
                exec "$DROID_PATH" "$@"
              fi

              echo "Detecting latest Factory CLI version..." >&2

              ver_line="$(${pkgs.curl}/bin/curl -fsSL https://app.factory.ai/cli | ${pkgs.gnugrep}/bin/grep -m1 'VER=')" || {
                echo "Failed to fetch https://app.factory.ai/cli" >&2
                exit 1
              }

              ver="$(printf '%s\n' "$ver_line" | ${pkgs.gnused}/bin/sed -E 's/.*VER="([^"]+)".*/\1/')" || ver=""
              if [ -z "$ver" ]; then
                echo "Could not parse VER from: $ver_line" >&2
                exit 1
              fi

              echo "Using Factory CLI version: $ver (arch: ${arch})" >&2

              url="https://downloads.factory.ai/factory-cli/releases/$ver/linux/${arch}/droid"

              # Download fresh binary
              ${pkgs.curl}/bin/curl -fL -o "$DROID_PATH" "$url" || {
                echo "Failed to download droid from: $url" >&2
                exit 1
              }

              chmod +x "$DROID_PATH"

              # Patch interpreter for NixOS
              ${pkgs.patchelf}/bin/patchelf \
                --set-interpreter "${pkgs.stdenv.cc.bintools.dynamicLinker}" \
                "$DROID_PATH"

              chmod +x "$DROID_PATH"

              # Hand off to droid with all original args
              exec "$DROID_PATH" "$@"
            ''}";
          };
        }
      );

      # Optional: devShells for hacking on this flake
      devShells = forAllSystems (
        system:
        let
          pkgs = import nixpkgs { inherit system; };
        in
        {
          default = pkgs.mkShell {
            packages = [
              pkgs.curl
              pkgs.patchelf
              pkgs.gnugrep
              pkgs.gnused
            ];
          };
        }
      );
    };
}
