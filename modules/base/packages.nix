{
  # NixOS
  flake.modules.nixos.base = {pkgs, ...}: {
    # OS Level Packages
    environment.systemPackages = with pkgs; [
      xdg-utils
      wget
      curl
      zip
      unzip
      jq
      yq
      gnumake
      bash
      dnsutils
    ];
  };

  # Home Manager
  flake.modules.homeManager.base = {...}: {
    # User Level Packages
    home.packages = [];
  };
}
