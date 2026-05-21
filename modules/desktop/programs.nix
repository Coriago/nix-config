# Main file for enabling programs and applications in the desktop environment
{inputs, ...}: {
  # NixOS
  flake.modules.nixos.desktop-extras = {
    pkgs,
    config,
    ...
  }: {
    # LLM Tools
    nixpkgs.overlays = [
      inputs.llm-agents.overlays.default
    ];
    environment.systemPackages = with pkgs; [
      usbutils
      gcc
      qemu
      disko
      rpi-imager
      xhost
      llm-agents.oh-my-opencode
      llm-agents.opencode
      gh
    ];
    programs = {
      usbtop.enable = true;
    };
    services.flatpak.packages = [
      "com.stremio.Stremio" # Stremio
    ];
    # Tailscale
    services.tailscale.enable = true;
    # networking.nameservers = ["100.100.100.100" "192.168.8.1" "1.1.1.1"];
    # networking.search = ["taila777b2.ts.net"];
  };

  # Home Manager
  flake.modules.homeManager.desktop-extras = {pkgs, ...}: {
    programs = {
      kubecolor.enable = true;
      k9s.enable = true;
      vscode.enable = true;
      discord.enable = true;
      nushell.enable = true;
      btop.enable = true;
      firefox.enable = true;
    };

    home.sessionVariables = {
      BROWSER = "brave";
      EDITOR = "code -w";
    };

    home.packages = with pkgs; [
      brave
      vlc
      realvnc-vnc-viewer
      orca-slicer
      krita
      element-desktop

      # Dev stuff
      kubectl
      devenv
    ];

    # programs.zsh. = "";
  };
}
