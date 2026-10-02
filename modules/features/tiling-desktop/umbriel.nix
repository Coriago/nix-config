{
  config,
  self,
  ...
}: let
  local = config;
in {
  flake.wrappers.myumbriel = {
    config,
    pkgs,
    lib,
    wlib,
    ...
  }: let
    noctalia = lib.getExe config.noctaliaPackage;
    settings = (pkgs.formats.toml {}).generate "umbriel-config.toml" {
      general.autostart = [noctalia];
      keybinds = {
        "Mod+Return" = "spawn:${lib.getExe pkgs.ghostty}";
        "Mod+Q" = "window-close";
        "Mod+S" = "spawn:${noctalia} ipc call launcher toggle";
        "Mod+Escape" = "session-quit";
        "Mod+Left" = "window-focus-left";
        "Mod+Right" = "window-focus-right";
        "Mod+Up" = "window-focus-up";
        "Mod+Down" = "window-focus-down";
        "Mod+F" = "window-toggle-fullscreen";
        "Mod+O" = "overview-toggle";
      };
    };
  in {
    imports = [wlib.modules.default];
    options.noctaliaPackage = lib.mkOption {
      type = lib.types.package;
      default = self.packages.${pkgs.stdenv.hostPlatform.system}.mynoctalia;
      description = "Noctalia wrapper used for autostart and IPC keybinds.";
    };
    config = {
      package = pkgs.umbriel;
      passthru.providedSessions = pkgs.umbriel.providedSessions;
      # Commands such as `msg`/`validate` require the subcommand first.
      runShell = [
        ''
          case "''${1-}" in
            ""|-*) set -- -c ${settings} "$@" ;;
            validate) shift; set -- validate -c ${settings} "$@" ;;
          esac
        ''
      ];
    };
  };

  flake.modules.nixos.umbriel = {
    config,
    lib,
    pkgs,
    ...
  }: {
    programs.umbriel = {
      enable = true;
      package = self.packages.${pkgs.stdenv.hostPlatform.system}.myumbriel.wrap {
        noctaliaPackage = config.wrappers.mynoctalia.wrapper;
      };
    };
    # The upstream unit embeds its original store path, bypassing the wrapper.
    # Reset ExecStart before replacing it in the generated systemd drop-in.
    systemd.user.services.umbriel.serviceConfig.ExecStart = [
      ""
      (lib.getExe config.programs.umbriel.package)
    ];
    services.displayManager.defaultSession = lib.mkForce "umbriel";
  };

  perSystem = {
    pkgs,
    lib,
    ...
  }: {
    checks.myumbriel = pkgs.runCommand "umbriel-config-check" {} ''
      export HOME="$TMPDIR/home"
      mkdir -p "$HOME"
      ${lib.getExe (local.flake.wrappers.myumbriel.wrap {inherit pkgs;})} validate
      touch "$out"
    '';
  };
}
