{
  inputs,
  lib,
  meta,
  ...
}: {
  flake.modules.nixos.nix = {
    config,
    hostmeta,
    ...
  }: let
    keepGenerations = 8;
  in {
    nixpkgs.config.allowUnfree = true;

    # Signing Packages
    sops.secrets.nix_signing_key = {};
    nix.extraOptions = ''
      builders-use-substitutes = true
      secret-key-files = ${config.sops.secrets.nix_signing_key.path}
    '';

    # Garbage Collection
    boot.loader.systemd-boot.configurationLimit = keepGenerations;
    programs.nh = {
      enable = true;
      flake = hostmeta.flakePath;
      clean = {
        enable = true;
        extraArgs = "--keep ${toString keepGenerations} --keep-since 3d";
      };
    };

    nix.settings = {
      nix-path = ["nixpkgs=${inputs.nixpkgs}"];
      auto-optimise-store = true;
      connect-timeout = 5;
      download-attempts = 2;
      stalled-download-timeout = 30;
      fallback = true;

      # Enable flakes
      experimental-features = ["nix-command" "flakes"];

      # Additional nix caches to fetch from
      trusted-users = ["${hostmeta.username}" "@wheel"]; # Required to allow for more caches
      substituters =
        lib.optional (meta.binaryCache.enable && hostmeta.hostname != meta.binaryCache.host.hostname) meta.binaryCache.url
        ++ [
          # official
          "https://cache.nixos.org?priority=10"
          "https://nixpkgs-python.cachix.org"

          # community
          "https://nix-community.cachix.org"
          "https://cache.numtide.com"

          # for rpi-selfhost nvmd
          "https://nixos-raspberrypi.cachix.org"
        ];
      trusted-public-keys =
        lib.optional meta.binaryCache.enable meta.binaryCache.publicKey
        ++ [
          "nixpkgs-python.cachix.org-1:hxjI7pFxTyuTHn2NkvWCrAUcNZLNS3ZAvfYNuYifcEU="
          "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
          "niks3.numtide.com-1:DTx8wZduET09hRmMtKdQDxNNthLQETkc/yaX7M4qK0g="
          "nixos-raspberrypi.cachix.org-1:4iMO9LXa8BqhU+Rpg6LQKiGa2lsNh/j2oiYLNOQ5sPI="
        ];
    };

    # Allows nixos rebuild without password
    security.sudo.extraRules = [
      {
        users = [hostmeta.username];
        commands = [
          {
            command = "/run/current-system/sw/bin/nixos-rebuild";
            options = ["NOPASSWD"];
          }
          {
            command = "/run/current-system/sw/bin/nixos";
            options = ["NOPASSWD"];
          }
        ];
      }
    ];

    # Nix tooling
  };
}
