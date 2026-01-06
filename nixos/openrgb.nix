{
  pkgs,
  config,
  lib,
  ...
}: {
  services.hardware.openrgb = {
    enable = true;
    package = pkgs.openrgb-with-all-plugins;
    motherboard = "amd";
    server = {
      port = 6745;
    };
  };
  environment.systemPackages = with pkgs; [
    i2c-tools
  ];
  users.groups.i2c.members = ["${config.var.username}" "root"];
  systemd.services.openrgb.serviceConfig.AmbientCapabilities = "CAP_SYS_RAWIO";
  systemd.services.openrgb.serviceConfig.CapabilityBoundingSet = "CAP_SYS_RAWIO";
  systemd.services.openrgb.serviceConfig.DeviceAllow = "/dev/i2c-* rw";
  services.udev.extraRules = builtins.readFile "${pkgs.openrgb}/lib/udev/rules.d/60-openrgb.rules";

  # services.hardware.openrgb = {
  #   package = pkgs.openrgb.overrideAttrs (old: {
  #     src = pkgs.fetchFromGitLab {
  #       owner = "CalcProgrammer1";
  #       repo = "OpenRGB";
  #       rev = "release_candidate_1.0rc2";
  #       sha256 = "sha256-vdIA9i1ewcrfX5U7FkcRR+ISdH5uRi9fz9YU5IkPKJQ=";
  #     };
  #     # patches = [
  #     #   ./remove_systemd_service.patch
  #     # ];
  #     postPatch = ''
  #       patchShebangs scripts/build-udev-rules.sh
  #       substituteInPlace scripts/build-udev-rules.sh \
  #        --replace-fail /usr/bin/env "${pkgs.coreutils}/bin/env"
  #     '';
  #     version = "1.0rc2";
  #   });
  #   enable = true;
  #   motherboard = "amd";
  # };
  # systemd.services.openrgb = lib.mkDefault {
  #   wantedBy = ["multi-user.target"];
  #   after = ["network.target" "lm_sensors.service"];
  #   description = "OpenRGB SDK Server";
  #   serviceConfig = {
  #     RemainAfterExit = "yes";
  #     ExecStart = ''${pkgs.openrgb}/bin/openrgb --server'';
  #     Restart = "always";
  #   };
  # };
}
