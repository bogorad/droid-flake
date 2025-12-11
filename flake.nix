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

              # Work in a predictable directory - /tmp
              EXECUTABLE_DIRECTORY="/tmp"
              mkdir -p "$EXECUTABLE_DIRECTORY"
              DROID_PATH="$EXECUTABLE_DIRECTORY/droid"

              # Function to get the latest version from the web
              get_latest_version() {
                local url="https://app.factory.ai/cli"
                
                # Fetch version and HTTP code in one go
                read -r ver code <<< "$(${pkgs.curl}/bin/curl --silent --write-out " %{http_code}" "$url" | ${pkgs.gawk}/bin/awk -F'"' '/VER=/ {v=$2} END {print v$0}')"
                
                if [ "$code" = "200" ] && [ -n "$ver" ]; then
                  echo "$ver"
                else
                  echo "Failed to fetch version (HTTP $code)" >&2
                  return 1
                fi
              }

              # Function to get the local version
              get_local_version() {
                if [ -x "$DROID_PATH" ]; then
                  "$DROID_PATH" --version 2>&1 | tail -1 || echo ""
                else
                  echo ""
                fi
              }

              # Function to download and install droid
              install_droid() {
                local ver="$1"
                
                url="https://downloads.factory.ai/factory-cli/releases/$ver/linux/${arch}/droid"
                
                ${pkgs.curl}/bin/curl -fL -o "$DROID_PATH" "$url" 2>&- || {
                  echo "Failed to download droid from: $url" >&2
                  return 1
                }
                
                chmod +x "$DROID_PATH"
                
                ${pkgs.patchelf}/bin/patchelf \
                  --set-interpreter "${pkgs.stdenv.cc.bintools.dynamicLinker}" \
                  "$DROID_PATH"
                
                chmod +x "$DROID_PATH"
              }

              # Check if we need to update
              local_version="$(get_local_version)"

              if [ -z "$local_version" ]; then
                # No local version, install
                echo "Installing Factory CLI..." >&2
                latest_version="$(get_latest_version)"
                install_droid "$latest_version"
                echo "Installed Factory CLI version: $latest_version" >&2
              else
                # Check for updates
                latest_version="$(get_latest_version)"
                
                if [ "$local_version" != "$latest_version" ]; then
                  echo "Updating Factory CLI from $local_version to $latest_version..." >&2
                  install_droid "$latest_version"
                fi
              fi

              # --- Symlink rg (ripgrep) ---
              # Ensure target directories exist
              mkdir -p "$HOME/.factory/bin"
              mkdir -p "$HOME/.local/bin"

              # Create symlinks to the nixpkgs ripgrep binary
              ln -sf "${pkgs.ripgrep}/bin/rg" "$HOME/.factory/bin/rg"
              ln -sf "${pkgs.ripgrep}/bin/rg" "$HOME/.local/bin/rg"
              # ----------------------------

              # Hand off to droid with all original args
              exec "$DROID_PATH" "$@"
            ''}";
          };
        }
      );
    };
}
