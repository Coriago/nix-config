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
      devenv
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
      (pkgs.symlinkJoin {
        name = "orca-slicer-wrapped";
        paths = [pkgs.orca-slicer];
        buildInputs = [pkgs.makeWrapper];
        postBuild = ''
          wrapProgram $out/bin/orca-slicer \
            --set __GLX_VENDOR_LIBRARY_NAME mesa \
            --set __EGL_VENDOR_LIBRARY_FILENAMES "${pkgs.mesa}/share/glvnd/egl_vendor.d/50_mesa.json" \
            --set MESA_LOADER_DRIVER_OVERRIDE zink \
            --set GALLIUM_DRIVER zink \
            --set WEBKIT_DISABLE_DMABUF_RENDERER 1
        '';
      })
      # --set GBM_BACKEND dri

      (pkgs.symlinkJoin {
        name = "bambu-studio-wrapped";
        paths = [pkgs.bambu-studio];
        buildInputs = [pkgs.makeWrapper];
        postBuild = ''
          wrapProgram $out/bin/bambu-studio \
            --set __GLX_VENDOR_LIBRARY_NAME mesa \
            --set __EGL_VENDOR_LIBRARY_FILENAMES "${pkgs.mesa}/share/glvnd/egl_vendor.d/50_mesa.json" \
            --set MESA_LOADER_DRIVER_OVERRIDE zink \
            --set GALLIUM_DRIVER zink \
            --set WEBKIT_DISABLE_DMABUF_RENDERER 1
        '';
      })
      # bambu-studio

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
