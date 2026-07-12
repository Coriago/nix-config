{
  inputs,
  config,
  ...
}: let
  hostname = "heliosdesk";
  username = "helios";
in {
  # Global Variables module
  ############################
  flake.modules.generic.${hostname} = {
    imports = with config.flake.modules; [generic.variables];
    vars = {
      username = username;
      stateVersion = "25.11";
      timeZone = "America/New_York";
      locale = "en_US.UTF-8";
      email = "gagemiller155@gmail.com";
      theme = "equilibrium-dark";
      wallpaper = "https://cdn.wallpapersafari.com/4/44/JgEZQu.jpg";
      wallpaperHash = "sha256-htjVJhbzfLtWTLt9G9252pLG1u8m9aHlHUYgoDytDBU=";
    };
  };

  # Nixos host configuration
  ###############################
  flake.modules.nixos.${hostname} = {
    pkgs,
    lib,
    ...
  }: {
    # Import nixos modules for this host
    imports = with config.flake.modules; [
      generic.${hostname}
      nixos.base
      nixos.base-homemanager
      nixos.desktop
      nixos.desktop-extras
      # nixos.self-hosting
      # nixos.self-hosting-agent

      # Drivers
      nixos.gpu
      nixos.boot
      # nixos.openrgb
      # nixos.vmtest
      # nixos.gaomon
      # nixos.cachyos
    ];

    home-manager.users.${username} = {
      # Import Home Manager modules
      imports = with config.flake.modules; [
        generic.${hostname}
        homeManager.base
        homeManager.desktop
        homeManager.desktop-extras
      ];
    };

    # Host Overrides
    #----------------------------------#
    networking.hostName = hostname;

    # Disable integrated AMD iGPU
    boot.blacklistedKernelModules = ["amdgpu"];
    boot.kernelParams = ["module_blacklist=amdgpu"];

    # Allow cross platform building
    boot.binfmt.emulatedSystems = ["aarch64-linux"];

    # TEMPORARY REMOVE - For Resume Matcher
    networking.firewall.allowedTCPPorts = [3000 8000 8123];
    networking.firewall.allowedUDPPorts = [3000 8000 8123];

    # BIOS Util
    services.fwupd.enable = true;

    # Monitor control
    hardware.i2c.enable = true;
    environment.systemPackages = with pkgs; [
      ddcutil
      ddcui
    ];

    # Bluetooth
    hardware.bluetooth = {
      enable = true;
      powerOnBoot = true;
    };

    # Quick Home Assistant setup for testing

    # virtualisation.oci-containers = {
    #   backend = "docker";
    #   containers.homeassistant = {
    #     volumes = [
    #       "home-assistant:/config"
    #       "/run/dbus:/run/dbus:ro"
    #     ];
    #     devices = [
    #       "/dev/serial/by-id/usb-Itead_Sonoff_Zigbee_3.0_USB_Dongle_Plus_V2_cca104ee7591f01189e1b77629b3d7e9-if00-port0:/dev/ttyUSB0"
    #     ];
    #     capabilities = {
    #       NET_ADMIN = true;
    #       NET_RAW = true;
    #     };
    #     environment.TZ = "Europe/Berlin";
    #     # Note: The image will not be updated on rebuilds, unless the version label changes
    #     image = "ghcr.io/home-assistant/home-assistant:stable";
    #     extraOptions = [
    #       # Use the host network namespace for all sockets
    #       "--network=host"
    #       # Pass devices into the container, so Home Assistant can discover and make use of them
    #       # "--device=/dev/ttyACM0:/dev/ttyACM0"
    #     ];
    #   };
    # };
  };

  # Final Configuration
  ######################
  flake.nixosConfigurations.${hostname} = inputs.nixpkgs.lib.nixosSystem {
    modules = [
      config.flake.modules.nixos.${hostname} # The module defined above
    ];
  };
}
