{
  # Make nixos easier and more compatible with debian.
  # Not the nix way but it is easier
  flake.modules.nixos.desktop = {
    pkgs,
    config,
    ...
  }: {
    programs.nix-ld.enable = true;
    # Common Dynamic Libraries for Desktop Programs
    programs.nix-ld.libraries = with pkgs; [
      stdenv.cc.cc.lib
      zlib
      glib
      fuse3
      icu
      nss
      openssl
      curl
      expat
      binutils
      lld
      linuxHeaders
      gsettings-desktop-schemas
      libGL
      libGLU
      libx11
      libxcursor
      libxext
      libxrandr
      libglvnd
      libxcb
      libxml2_13
      libxt
      lsb-release
      util-linux
      vulkan-loader
      xdg-utils
      xterm
      zenity
      xterm
      alsa-lib
      libpulseaudio
      udev
      # wayland
      gcc
      gnumake
      libva-utils
      webkitgtk_4_1
      libsoup_3
      libwebp

      # Python
      python312
      python312Packages.pip
      python312Packages.virtualenv
      python312Packages.requests
      cudaPackages_12_8.cudatoolkit

      linuxPackages.nvidia_x11
      mesa
      addDriverRunpath
      cacert
      libxcrypt-legacy
    ];

    environment.systemPackages = with pkgs; [
      apt
      util-linux
      zenity
      vulkan-headers
    ];
    environment.sessionVariables = {
      VK_ICD_FILENAMES = "/run/opengl-driver/share/vulkan/icd.d/nvidia_icd.json";
    };

    hardware.graphics = {
      extraPackages = with pkgs; [
        vulkan-loader
        vulkan-validation-layers
        vulkan-extension-layer
      ];
    };

    services.envfs.enable = true;

    # AppImage Support
    programs.appimage = {
      enable = true;
      binfmt = false;
      package =
        pkgs.appimage-run.override
        {
          extraPkgs = pkgs: config.programs.nix-ld.libraries;
        };
    };
  };
}
