# Desktop UI Apps
{
  # NixOS
  flake.modules.nixos.desktop = {
    pkgs,
    config,
    ...
  }: {
    programs.usbtop.enable = true;
    environment.systemPackages = with pkgs; [
      usbutils
      python311
      gcc
    ];

    # Docker
    virtualisation.docker = {
      enable = true;
      autoPrune.enable = true;
      enableNvidia = true;
    };

    users.users.${config.vars.username}.extraGroups = ["docker"];

    # Direnv
    programs.direnv = {
      enable = true;
      enableZshIntegration = true;
      nix-direnv.enable = true;
    };
  };

  # Home Manager
  flake.modules.homeManager.desktop = {pkgs, ...}: {
    home.packages = with pkgs; [
      vlc
      discord
      kitty
      rpi-imager
      kubectl
      k9s
      realvnc-vnc-viewer
      opencode
      devenv

      # Node.js for VS Code extension development
      # TODO: Move out into direnv flake
      nodejs_22
      nodePackages.typescript
      nodePackages.typescript-language-server
      vsce # VS Code Extension Manager
    ];

    programs.vscode = {
      enable = true;
      mutableExtensionsDir = true;
      profiles.default.extensions = with pkgs.vscode-extensions; [
        jnoortheen.nix-ide
        christian-kohler.path-intellisense

        # TypeScript / Node.js development
        dbaeumer.vscode-eslint
        esbenp.prettier-vscode
      ];
    };
  };
}
