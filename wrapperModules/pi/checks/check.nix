{config, ...}: let
  local = config;
in {
  perSystem = {
    pkgs,
    lib,
    ...
  }: let
    fixture = local.flake.wrappers.pi.wrap {
      inherit pkgs;
      agentDir = "\${HOME}/agent with spaces";
      snapshot.enable = true;
      snapshot.defaultDir = "\${HOME}/captured";
      snapshot.sourceDir = ./baseline;
      settings.compaction.enabled = false;
      keybindings."app.session.new" = "ctrl+shift+n";
      extensions = [./probe.ts];
    };
    restore = fixture.wrap ({
      config,
      lib,
      ...
    }: {
      agentDir = lib.mkForce "\${HOME}/restored";
      sync.files.piSettings.sources = [
        "\${HOME}/captured/settings.json"
        config.constructFiles.piSettings.path
      ];
    });
    browser = fixture.wrap {
      chromeDevtools.server = pkgs.writeShellScriptBin "chrome-devtools-mcp" "exit 0";
      chromeDevtools.settings.headless = true;
    };
  in {
    checks.pi-wrapper =
      pkgs.runCommand "pi-wrapper-check" {
        nativeBuildInputs = [pkgs.python3];
      } ''
        python ${./check.py} ${lib.getExe fixture} ${fixture}/bin/pi-snapshot \
          ${lib.getExe restore} ${lib.getExe browser} ${browser}/bin/pi-snapshot
        touch "$out"
      '';
  };
}
