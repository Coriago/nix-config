# Main file for enabling programs and applications in the desktop environment
{inputs, ...}: {
  # NixOS
  flake.modules.nixos.desktop = {
    pkgs,
    config,
    ...
  }: {
    environment.systemPackages = with pkgs; [
      usbutils
      gcc
      qemu
      disko
      rpi-imager
      xhost
    ];

    services.flatpak.packages = [
      "com.stremio.Stremio" # Stremio
    ];
  };

  # Home Manager
  flake.modules.homeManager.desktop = {pkgs, ...}: {
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
      btop.enable = true;
      brave = {
        enable = true;
        extensions = [
          {id = "cjpalhdlnbpafiamejdnhcphjbkeiagm";} # ublock origin
          {id = "nngceckbapebfimnlniiiahkandclblb";} # bitwarden
        ];
      };
      firefox.enable = true;
    };
    home.sessionVariables = {
      BROWSER = "brave";
      EDITOR = "code -w";
    };

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
  };
}
