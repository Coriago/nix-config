{inputs, ...}: {
  flake.modules.nixos.surface-kernel = {
    config,
    lib,
    pkgs,
    ...
  }: let
    source = inputs.linux-surface;
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
      })
      patches
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
        {
          name = "surface-unused-hardware";
          patch = null;
          structuredExtraConfig = lib.genAttrs [
            # Keep i915, the external NVIDIA module, and virtual/USB displays.
            "DRM_AMDGPU"
            "DRM_RADEON"
            "DRM_NOUVEAU"
            "DRM_XE"
            "DRM_ACCEL_AMDXDNA"
            "DRM_ACCEL_HABANALABS"
            "DRM_ACCEL_IVPU"
            "DRM_ACCEL_QAIC"

            # Keep cameras, video capture, HDMI CEC, and remote controls.
            "MEDIA_ANALOG_TV_SUPPORT"
            "MEDIA_DIGITAL_TV_SUPPORT"
            "MEDIA_RADIO_SUPPORT"

            # Legacy/specialist Wi-Fi; retain common PCIe and USB adapter families.
            "WLAN_VENDOR_ADMTEK"
            "WLAN_VENDOR_ATMEL"
            "WLAN_VENDOR_INTERSIL"
            "WLAN_VENDOR_MICROCHIP"
            "WLAN_VENDOR_MORSEMICRO"
            "WLAN_VENDOR_PURELIFI"
            "WLAN_VENDOR_QUANTENNA"
            "WLAN_VENDOR_SILABS"
            "WLAN_VENDOR_ST"
            "WLAN_VENDOR_TI"

            # Physical datacenter RDMA adapters only; keep core/software RDMA,
            # Ethernet, storage protocols, RAID, filesystems, and BPF/BTF intact.
            "INFINIBAND_BNXT_RE"
            "INFINIBAND_BNG_RE"
            "INFINIBAND_CXGB4"
            "INFINIBAND_EFA"
            "INFINIBAND_ERDMA"
            "INFINIBAND_HFI1"
            "INFINIBAND_HNS_HIP08"
            "INFINIBAND_IONIC"
            "INFINIBAND_IRDMA"
            "INFINIBAND_MTHCA"
            "INFINIBAND_OCRDMA"
            "INFINIBAND_QEDR"
            "INFINIBAND_USNIC"
            "MLX4_INFINIBAND"
            "MLX5_INFINIBAND"
          ] (_: lib.mkForce lib.kernel.no);
        }
      ];

    services.iptsd.enable = lib.mkDefault true;
    # Preserve both across change events; IPTSd stops when its device no longer wants it.
    services.udev.extraRules = lib.mkIf config.services.iptsd.enable ''
      ACTION!="remove", SUBSYSTEM=="hidraw", KERNELS=="0001:045E:0C5D.*|0001:045E:0C46.*", TAG+="systemd", ENV{SYSTEMD_WANTS}+="iptsd@dev-%k.service"
    '';
    hardware.enableRedistributableFirmware = lib.mkDefault true;
    hardware.sensor.iio.enable = lib.mkDefault true;
  };
}
