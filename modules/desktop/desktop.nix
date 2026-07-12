# Linux Desktop Environment
# Other possible desktop environments: Gnome, KDE Plasma, Hyperland, Niri, etc.
{inputs, ...}: {
  # NixOS
  flake.modules.nixos.desktop = {
    config,
    pkgs,
    ...
  }: {
    # Uses KDE Plasma for Desktop
    services.xserver.enable = true;
    services.desktopManager.plasma6.enable = true;
    services.displayManager.plasma-login-manager.enable = true;
    services.displayManager.autoLogin.user = config.vars.username;
    services.fprintd.enable = true;
    programs.kdeconnect.enable = true;
    programs.partition-manager.enable = true;
    environment.systemPackages = with pkgs; [
      systemdgenie
      kdePackages.print-manager
      yazi
      # neovim
      # ripgrep
      # fd
      # fzf
      k3s
    ];

    # Printer
    services.printing.enable = true;
    services.printing.drivers = with pkgs; [hplip];

    # Audio
    security.rtkit.enable = true;

    # Enable x11
    services.xserver = {
      xkb.layout = config.vars.keyLayout;
      xkb.variant = "";
    };

    # Networking for non-headless
    networking.networkmanager.enable = true;
    services.avahi = {
      nssmdns4 = true;
      enable = true;
      ipv4 = true;
      ipv6 = true;
      publish = {
        enable = true;
        addresses = true;
        workstation = true;
      };
    };
  };

  # flake.apps.fdsf = {...}: {

  # };

  # flake.wrappers.lazyvim = {wlib, ...}: {
  #   imports = [wlib.wrapperModules.neovim];
  # };

  # perSystem = {
  #   pkgs,
  #   lib,
  #   self',
  #   ...
  # }: {
  #   # packages.myneovim = ;
  #   # wrappers.
  # };

  # perSystem
}
