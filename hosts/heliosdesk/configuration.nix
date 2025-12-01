{
  config,
  pkgs,
  ...
}: {
  imports = [
    # Mostly system related configuration
    ../../nixos/nvidia.nix
    ../../nixos/audio.nix
    ../../nixos/bluetooth.nix
    # ../../nixos/fonts.nix
    ../../nixos/home-manager.nix
    ../../nixos/nix.nix
    ../../nixos/systemd-boot.nix
    ../../nixos/users.nix
    ../../nixos/utils.nix
    ../../nixos/tailscale.nix
    # ../../nixos/sddm.nix
    # ../../nixos/hyprland.nix
    ../../nixos/gnome.nix
    ../../nixos/docker.nix
    ../../nixos/steam.nix
    ../../nixos/flatpak.nix

    # ../../nixos/omen.nix # For my laptop only

    # You should let those lines as is
    ./hardware-configuration.nix
    ./variables.nix
  ];

  home-manager.users."${config.var.username}" = import ./home.nix;

  programs.nix-ld = {
    enable = true;
    # libraries = with pkgs; [
    #   libxcrypt
    #   libcryptui
    # ];
  };
  # Don't touch this
  system.stateVersion = "25.05";
}
