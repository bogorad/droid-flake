# droid-flake

Runnable Droid (Factory CLI) launcher for NixOS on x86_64 and aarch64.

## What it does

This flake provides a `nix run`-able wrapper that:
- Detects the latest Factory CLI (Droid) version.
- Downloads the correct Linux binary for your architecture.
- Patches the binary's interpreter for NixOS compatibility.
- Caches the binary locally in `./droid` and reuses it on subsequent runs.

## Requirements

- Nix with flake support enabled.
- NixOS (x86_64-linux or aarch64-linux).

## Usage

Run Droid via this flake:

```bash
nix run github:bogorad/droid-flake -- [droid-args]
```

Or from a local clone:

```bash
git clone https://github.com/bogorad/droid-flake
cd droid-flake
nix run . -- [droid-args]
```

The first run will download and patch the Droid binary into `./droid`; later runs reuse it.
