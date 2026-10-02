{config, ...}: let
  local = config;
in {
  flake.wrappers.mynoctalia = {
    config,
    lib,
    pkgs,
    wlib,
    ...
  }: {
    imports = [wlib.wrapperModules.noctalia-shell];

    options.settingsFile = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Direct settings path; null seeds writable user settings from the committed JSON.";
    };

    config = {
      # Direct paths allow atomic GUI saves into the checkout in liveConfig mode.
      env.NOCTALIA_SETTINGS_FILE = lib.mkIf (config.settingsFile != null) config.settingsFile;

      # Remote/standalone runs need no checkout. Seed once, preserving GUI edits.
      runShell = lib.mkIf (config.settingsFile == null) [
        ''
          export NOCTALIA_SETTINGS_FILE="''${XDG_CONFIG_HOME:-$HOME/.config}/mynoctalia/settings.json"
          if [ ! -e "$NOCTALIA_SETTINGS_FILE" ]; then
            ${pkgs.coreutils}/bin/mkdir -p "$(${pkgs.coreutils}/bin/dirname "$NOCTALIA_SETTINGS_FILE")" || exit 1
            ${pkgs.coreutils}/bin/install -m 600 ${./noctalia-settings.json} "$NOCTALIA_SETTINGS_FILE" || exit 1
          fi
        ''
      ];
    };
  };

  perSystem = {pkgs, lib, ...}: let
    # Exercise the real wrapper without starting a shell on the builder's display.
    probe = pkgs.writeShellScriptBin "noctalia-shell" ''
      exec ${pkgs.python3}/bin/python ${./noctalia-check.py} --app "$@"
    '';
    portable = local.flake.wrappers.mynoctalia.wrap {
      inherit pkgs;
      package = probe;
    };
    livePath = "/tmp/noctalia live check/settings.json";
    live = portable.wrap {settingsFile = livePath;};
  in {
    checks.mynoctalia = pkgs.runCommand "noctalia-settings-check" {} ''
      export HOME="$TMPDIR/home"
      mkdir -p "$HOME"
      ${pkgs.python3}/bin/python ${./noctalia-check.py} \
        ${lib.getExe' portable "noctalia-shell"} \
        ${lib.getExe' live "noctalia-shell"} \
        ${./noctalia-settings.json} ${lib.escapeShellArg livePath}
      touch "$out"
    '';
  };

  flake.modules.nixos.noctalia = {config, ...}: {
    imports = [local.flake.wrappers.mynoctalia.install];

    wrappers.mynoctalia = {
      enable = true;
      settingsFile =
        if config.liveConfig.enable
        then "${config.liveConfig.root}/modules/features/tiling-desktop/noctalia-settings.json"
        else toString ./noctalia-settings.json;
    };
  };
}
