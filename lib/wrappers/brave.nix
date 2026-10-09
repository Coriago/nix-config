# Brave-specific paths and HM extraction. Personal choices belong in the feature's config/.
{home-manager}: {
  config,
  lib,
  pkgs,
  wlib,
  ...
}: let
  json = pkgs.formats.json {};
  hm = home-manager.lib.homeManagerConfiguration {
    inherit pkgs;
    modules = [
      {
        home = {
          username = "mybrave";
          homeDirectory = "/var/empty/mybrave";
          stateVersion = "26.05";
        };
        xdg.enable = true;
        programs.brave.enable = true;
      }
      config.homeManager
    ];
  };
  browser = hm.config.programs.brave;
  failures = map (a: a.message) (lib.filter (a: !a.assertion) hm.config.assertions);
  hmFiles = assert lib.assertMsg (failures == []) (lib.concatStringsSep "\n" failures);
  assert lib.assertMsg (browser.enable && browser.finalPackage != null) "The Brave adapter requires programs.brave and its package";
  assert lib.assertMsg (!(lib.any (arg: lib.any (prefix: lib.hasPrefix prefix arg) ["--user-data-dir" "--profile-directory"] || arg == "--") browser.commandLineArgs))
  "Use userDataDir/profileDirectory or launcher flags instead of hiding profile flags in HM commandLineArgs";
    hm.config.home-files;
  hmProfile = "${hmFiles}/${lib.removePrefix "${hm.config.home.homeDirectory}/" hm.config.xdg.configHome}/BraveSoftware/Brave-Browser";
  settings = json.generate "brave-preferences.json" config.settings;
  managed = json.generate "brave-managed.json" config.managedPolicies;
  policyEnvironment = pkgs.buildFHSEnv {
    name = "mybrave-policy-env";
    targetPkgs = _: [];
    multiPkgs = _: [];
    multiArch = false;
    dieWithParent = false;
    runScript = "${pkgs.coreutils}/bin/env";
    # Brave's Linux policy location is fixed; HM does not expose these policies.
    extraBuildCommands = ''
      mkdir -p "$out/etc/brave/policies/managed"
      ln -s ${managed} "$out/etc/brave/policies/managed/wrapper.json"
      ln -s ${lib.escapeShellArg "${config.configDir}"} "$out/etc/brave/policies/recommended"
    '';
  };
in {
  imports = [./sync-snap.nix];
  options = {
    homeManager = lib.mkOption {
      type = lib.types.deferredModule;
      default = {};
      description = "HM module used to generate Brave's package and integration files, without activation.";
    };
    settings = lib.mkOption {
      type = json.type;
      default = {};
      description = "Native Preferences, layered after snapshotSource. HM has no programs.brave.settings option.";
    };
    snapshotSource = lib.mkOption {
      type = lib.types.path;
      default = pkgs.writeText "brave-empty-snapshot.json" "{}";
      description = "Captured preferences baseline to embed.";
    };
    configDir = lib.mkOption {
      type = lib.types.path;
      description = "Recommended policy JSON directory; may be a live checkout link.";
    };
    managedPolicies = lib.mkOption {
      type = json.type;
      default = {};
      description = "Small mandatory policy layer.";
    };
    userDataDir = lib.mkOption {
      type = lib.types.str;
      default = "\${XDG_CONFIG_HOME:-$HOME/.config}/mybrave";
      description = "Writable isolated browser data directory; runtime environment expansion is supported.";
    };
    profileDirectory = lib.mkOption {
      type = lib.types.strMatching "[^/]+";
      default = "Default";
      description = "Profile within userDataDir.";
    };
  };
  config = {
    package = lib.mkDefault browser.finalPackage;
    syncSnap = {
      program = "mybrave";
      commandPrefix = "brave";
      variables = {
        root = {
          value = config.userDataDir;
          flag = "--user-data-dir";
          kind = "path";
        };
        profile = {
          value = config.profileDirectory;
          flag = "--profile-directory";
          kind = "segment";
        };
      };
      skipSyncIfExists = lib.mkDefault "@root@/SingletonLock";
      sync =
        {
          preferences = {
            destination = "@root@/@profile@/Preferences";
            sources = [
              {
                path = "${config.snapshotSource}";
                format = "json";
              }
              {
                path = "${settings}";
                format = "json";
              }
            ];
            format = "json";
            policy = lib.mkOptionDefault "merge";
            trigger = lib.mkOptionDefault "on-start";
          };
        }
        // lib.genAttrs ["External Extensions" "NativeMessagingHosts" "Dictionaries"] (directory: {
          destination = "@root@/${directory}";
          sources = [
            {
              path = "${hmProfile}/${directory}";
              optional = true;
            }
          ];
          directory = true;
          format = "raw";
          policy = "replace";
          trigger = "on-start";
        });
      snapshot.preferences = {
        destination = lib.mkDefault ""; # Common helper requires an explicit output or snapshotFile.
        sources = [
          {
            path = "@root@/@profile@/Preferences";
            format = "json";
          }
        ];
        format = "json";
      };
    };
    flagSeparator = "=";
    flags."--user-data-dir" = {
      data = config.userDataDir;
      esc-fn = wlib.escapeShellArgWithEnv;
    };
    flags."--profile-directory" = config.profileDirectory;
    argv0type = command: "exec ${lib.getExe config.passthru.syncSnap.runner} launch ${lib.getExe policyEnvironment} ${command}";
    passthru = {
      inherit policyEnvironment;
      homeManagerFiles = hmFiles;
      homeManagerProfile = hmProfile;
      generatedConfig = settings;
      snapshotBaseline = config.snapshotSource;
      managedPolicyFile = managed;
      recommendedPolicyDirectory = config.configDir;
    };
  };
}
