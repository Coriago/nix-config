{
  config,
  inputs,
  self,
  ...
}: let
  local = config;
in {
  flake.modules.nixos.pi-agent = {
    config,
    lib,
    pkgs,
    ...
  }: {
    sops.secrets.context7 = {};
    environment.systemPackages = [
      (self.packages.${pkgs.stdenv.hostPlatform.system}.mypi.wrap {
        runShell = [
          ''
            if [ -r ${lib.escapeShellArg config.sops.secrets.context7.path} ]; then
              export CONTEXT7_API_KEY="$(< ${lib.escapeShellArg config.sops.secrets.context7.path})"
            fi
          ''
        ];
      })
    ];
  };

  perSystem = {
    pkgs,
    lib,
    self',
    ...
  }: let
    plugins = pkgs.buildNpmPackage {
      pname = "mypi-plugins";
      version = "1.0.0";
      src = ./plugins;
      npmDepsFetcherVersion = 2;
      npmDepsHash = "sha256-0YdKrZDcVPFfJlARYeI874CpDF6lZT+zuqtWDwe7Oys=";
      # Pi supplies its SDK; do not install a duplicate copy.
      npmFlags = ["--legacy-peer-deps"];
      npmInstallFlags = ["--ignore-scripts"];
      dontNpmBuild = true;
      installPhase = ''
        runHook preInstall
        mkdir -p "$out/share/pi-plugins"
        cp -r package.json node_modules "$out/share/pi-plugins/"
        runHook postInstall
      '';
    };
    browserServer = inputs.wrapper-modules.lib.wrapPackage {
      inherit pkgs;
      package = plugins;
      exePath = "share/pi-plugins/node_modules/chrome-devtools-mcp/build/src/bin/chrome-devtools-mcp.js";
      binName = "chrome-devtools-mcp";
      flags."--executablePath" = lib.getExe pkgs.chromium;
      env.CHROME_DEVTOOLS_MCP_NO_UPDATE_CHECKS = "1";
    };
  in {
    packages.mypi = local.flake.wrappers.pi.wrap {
      inherit pkgs;
      agentDir = "\${HOME}/.pi/agent";
      snapshot.enable = true;
      extensions = [
        "${plugins}/share/pi-plugins"
        ./config/context7.ts
      ];
      chromeDevtools = {
        server = browserServer;
        settings = builtins.fromJSON (builtins.readFile ./config/chrome-devtools.json);
      };
      runtimePkgs = [pkgs.git pkgs.nodejs pkgs.ripgrep];
      meta.description = "Pi with Chrome DevTools and Context7 MCP, web access, and user questions";
    };
    apps.mypi = {
      type = "app";
      program = lib.getExe self'.packages.mypi;
      meta.description = "Pi coding agent with bundled extensions";
    };
  };
}
