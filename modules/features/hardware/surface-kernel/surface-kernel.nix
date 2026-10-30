{
  flake.modules.nixos.surface-kernel = {
    config,
    lib,
    pkgs,
    ...
  }: let
    source = pkgs.fetchFromGitHub {
      owner = "linux-surface";
      repo = "linux-surface";
      rev = "8c62d84193a38bd097238b192a4f7262db8a9f7e";
      hash = "sha256-687H05hC6HDdOhJPG9C/bOszSdQy/YCWyf688mMytos=";
    };
    patches = [
      "0001-secureboot"
      "0002-surface3"
      "0003-mwifiex"
      "0004-ath10k"
      "0005-ipts"
      "0006-ithc"
      "0007-surface-sam"
      "0008-surface-sam-over-hid"
      "0009-surface-button"
      "0010-surface-typecover"
      "0011-surface-shutdown"
      "0012-surface-gpe"
      "0013-cameras"
      "0014-amd-gpio"
      "0015-hid-surface"
    ];
  in {
    assertions = [
      {
        assertion = lib.versions.majorMinor config.boot.kernelPackages.kernel.version == "7.3";
        message = "surface-kernel requires a Linux 7.3 kernel; update the Surface patchset before selecting another series.";
      }
    ];

    # A normal-priority kernel selection (including cachyos-kernel) takes precedence.
    boot.kernelPackages = lib.mkDefault pkgs.linuxPackages_7_3;
    boot.kernelPatches =
      map (name: {
        name = "surface-7.3/${name}";
        patch = "${source}/patches/7.3/${name}.patch";
      }) patches
      ++ [
        {
          name = "surface-7.3-config";
          patch = null;
          # Matches configs/surface-7.3.config at the pinned linux-surface revision.
          structuredExtraConfig =
            lib.genAttrs [
              "SURFACE_AGGREGATOR"
              "SURFACE_AGGREGATOR_CDEV"
              "SURFACE_AGGREGATOR_HUB"
              "SURFACE_AGGREGATOR_REGISTRY"
              "SURFACE_AGGREGATOR_TABLET_SWITCH"
              "SURFACE_ACPI_NOTIFY"
              "SURFACE_DTX"
              "SURFACE_PLATFORM_PROFILE"
              "SURFACE_HID"
              "SURFACE_KBD"
              "BATTERY_SURFACE"
              "CHARGER_SURFACE"
              "SENSORS_SURFACE_TEMP"
              "SENSORS_SURFACE_FAN"
              "RTC_DRV_SURFACE"
              "SURFACE_HOTPLUG"
              "HID_IPTS"
              "HID_ITHC"
              "INTEL_THC_HID"
              "INTEL_QUICKSPI"
              "VIDEO_DW9719"
              "VIDEO_IPU3_IMGU"
              "VIDEO_IPU3_CIO2"
              "IPU_BRIDGE"
              "INTEL_SKL_INT3472"
              "REGULATOR_TPS68470"
              "COMMON_CLK_TPS68470"
              "LEDS_TPS68470"
              "VIDEO_OV5693"
              "VIDEO_OV7251"
              "VIDEO_OV8865"
              "APDS9960"
              "INPUT_SOC_BUTTON_ARRAY"
              "SURFACE_3_POWER_OPREGION"
              "SURFACE_PRO3_BUTTON"
              "SURFACE_GPE"
              "SURFACE_BOOK1_DGPU_SWITCH"
              "HID_SURFACE"
            ] (_: lib.kernel.module)
            // {
              SURFACE_AGGREGATOR_BUS = lib.kernel.yes;
              SURFACE_AGGREGATOR_ERROR_INJECTION = lib.kernel.no;
              INTEL_ATOMISP = lib.kernel.no;
            };
        }
      ];

    services.iptsd.enable = lib.mkDefault true;
    # IPTSd's add-only rule loses the systemd tag on change, stopping both daemons.
    services.udev.extraRules = lib.mkIf config.services.iptsd.enable ''
      SUBSYSTEM=="hidraw", KERNELS=="0001:045E:0C5D.*|0001:045E:0C46.*", TAG+="systemd"
    '';
    hardware.enableRedistributableFirmware = lib.mkDefault true;
    hardware.sensor.iio.enable = lib.mkDefault true;
  };
}
