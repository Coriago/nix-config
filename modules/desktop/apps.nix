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
      qemu
      disko
      rpi-imager
    ];

    # Docker
    virtualisation.docker = {
      enable = true;
      autoPrune.enable = true;
    };

    users.users.${config.vars.username}.extraGroups = ["docker"];

    # Direnv
    programs.direnv = {
      enable = true;
      enableZshIntegration = true;
      nix-direnv.enable = true;
      silent = true;
    };
  };

  # Home Manager
  flake.modules.homeManager.desktop = {pkgs, ...}: {
    home.packages = with pkgs; [
      vlc
      realvnc-vnc-viewer
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

      # Dev stuff
      kubectl
      just
      just-lsp
      krita
      element-desktop
    ];

    programs = {
      kubecolor.enable = true;
      k9s.enable = true;
      opencode = {
        enable = true;
        enableMcpIntegration = true;
      };
      vscode.enable = true;
      discord.enable = true;
      nushell.enable = true;
    };
    stylix.targets.vscode.enable = false;
  };
}
