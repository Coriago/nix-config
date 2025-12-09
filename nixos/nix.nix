# Nix configuration for NixOS
{
  config,
  inputs,
  ...
}: let
  autoGarbageCollector = config.var.autoGarbageCollector;
in {
  boot.binfmt.emulatedSystems = ["aarch64-linux"];
  security.sudo.extraRules = [
    {
      users = [config.var.username];
      commands = [
        {
          command = "/run/current-system/sw/bin/nixos-rebuild";
          options = ["NOPASSWD"];
        }
      ];
    }
  ];
  nixpkgs.config = {
    allowUnfree = true;
    allowBroken = true;
  };
  nix = {
    nixPath = ["nixpkgs=${inputs.nixpkgs}"];
    channel.enable = false;
    extraOptions = ''
      warn-dirty = false
    '';
    settings = {
      download-buffer-size = 262144000; # 250 MB (250 * 1024 * 1024)
      auto-optimise-store = true;
      experimental-features = ["nix-command" "flakes"];
      trusted-users = ["root" "${config.var.username}" "@wheel"];
      extra-platforms = ["aarch64-linux"];
      # sandbox = false;
      substituters = [
        # high priority since it's almost always used
        "https://cache.nixos.org?priority=10"

        "https://hyprland.cachix.org"
        "https://nix-community.cachix.org"
        "https://numtide.cachix.org"
        "https://nixos-raspberrypi.cachix.org"
      ];
      trusted-public-keys = [
        "hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc="
        "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
        "numtide.cachix.org-1:2ps1kLBUWjxIneOy1Ik6cQjb41X0iXVXeHigGmycPPE="
        "nixos-raspberrypi.cachix.org-1:4iMO9LXa8BqhU+Rpg6LQKiGa2lsNh/j2oiYLNOQ5sPI="
      ];
    };
    gc = {
      automatic = autoGarbageCollector;
      persistent = true;
      dates = "weekly";
      options = "--delete-older-than 7d";
    };
  };
}
