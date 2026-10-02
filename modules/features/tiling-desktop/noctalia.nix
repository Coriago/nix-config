{config, ...}: let
  local = config;
in {
  flake.wrappers.mynoctalia = {
    config,
    lib,
    pkgs,
    wlib,
    ...
  }: let
    userConfigDir = "\${XDG_CONFIG_HOME:-$HOME/.config}/mynoctalia";
  in {
    imports = [wlib.wrapperModules.noctalia-shell];

    options.liveConfigDir = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Writable checkout directory; null uses the user's standalone config directory.";
    };

    config = {
      settings = builtins.fromJSON (builtins.readFile ./noctalia/settings.json);
      colors = builtins.fromJSON (builtins.readFile ./noctalia/colors.json);

      # Add pinned plugin sources here; GUI changes remain possible after copying.
      preInstalledPlugins = {};

      # Upstream autoCopyConfig (true by default) seeds missing files and keeps edits.
      # The pinned copy helper interpolates this as shell code, so quote the path.
      outOfStoreConfig = lib.mkDefault (
        if config.liveConfigDir == null
        then wlib.escapeShellArgWithEnv userConfigDir
        else lib.escapeShellArg config.liveConfigDir
      );
      runtimePkgs = [pkgs.coreutils pkgs.findutils];
      env.NOCTALIA_CONFIG_DIR = lib.mkIf (config.outOfStoreConfig != null) (lib.mkForce {
        data = "${if config.liveConfigDir == null then userConfigDir else config.liveConfigDir}/";
        esc-fn = if config.liveConfigDir == null then wlib.escapeShellArgWithEnv else lib.escapeShellArg;
      });
      unsetVar = ["NOCTALIA_SETTINGS_FILE"];
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
      preInstalledPlugins.test-plugin = {
        src = pkgs.writeTextDir "main.qml" "// Test fixture, not a runnable plugin.";
        settings = {fromNix = true;};
      };
    };
    livePath = "/tmp/noctalia live check";
    live = portable.wrap {liveConfigDir = livePath;};
    frozen = portable.wrap {outOfStoreConfig = null;};
  in {
    checks.mynoctalia = pkgs.runCommand "noctalia-settings-check" {} ''
      export HOME="$TMPDIR/home"
      mkdir -p "$HOME"
      ${pkgs.python3}/bin/python ${./noctalia-check.py} \
        ${lib.getExe' portable "noctalia-shell"} \
        ${lib.getExe' live "noctalia-shell"} \
        ${lib.getExe' frozen "noctalia-shell"} \
        ${./noctalia} ${lib.escapeShellArg livePath}
      touch "$out"
    '';
  };

  flake.modules.nixos.noctalia = {config, lib, ...}: {
    imports = [local.flake.wrappers.mynoctalia.install];

    wrappers.mynoctalia = {
      enable = true;
      liveConfigDir = lib.mkIf config.liveConfig.enable "${config.liveConfig.root}/modules/features/tiling-desktop/noctalia";
      outOfStoreConfig = lib.mkIf (!config.liveConfig.enable) null;
    };
  };
}
