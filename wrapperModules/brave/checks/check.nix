{config, ...}: let
  local = config;
in {
  perSystem = {
    pkgs,
    lib,
    ...
  }: let
    # Exercise the generic adapter independently of any personal feature.
    package = local.flake.wrappers.brave.wrap {
      inherit pkgs;
      userDataDir = "\${XDG_CONFIG_HOME}/wrapper-test/user-data";
      snapshot.enable = true;
      snapshot.autoMerge = false;
      preferences.credentials_enable_autosignin = false;
      extensions = [
        {
          id = "nngceckbapebfimnlniiiahkandclblb";
          installationMode = "force_installed";
        }
      ];
      recommendedPolicies = {
        PasswordManagerEnabled = false;
        DefaultSearchProviderEnabled = true;
        DefaultSearchProviderName = "Fixture Search";
        DefaultSearchProviderKeyword = "search.invalid";
        DefaultSearchProviderSearchURL = "https://search.invalid/?q={searchTerms}";
        HomepageLocation = "https://wrapper.invalid/";
        HomepageIsNewTabPage = false;
        ShowHomeButton = true;
      };
    };
    snapshotCheck = package.wrap {
      snapshot.defaultDir = "\${HOME}/snapshot";
    };
    contrast = package.wrap ({lib, ...}: {
      userDataDir = lib.mkForce "\${XDG_CONFIG_HOME}/contrast/user-data";
      recommendedPolicies = {
        HomepageLocation = lib.mkForce "https://contrast.invalid/";
        DefaultSearchProviderName = lib.mkForce "Contrast Search";
        DefaultSearchProviderKeyword = lib.mkForce "contrast.invalid";
        DefaultSearchProviderSearchURL = lib.mkForce "https://contrast.invalid/search?q={searchTerms}";
      };
      extensions = lib.mkForce [
        {
          id = "nngceckbapebfimnlniiiahkandclblb";
          installationMode = "force_installed";
        }
        {
          id = "pbfopnphnepmbmdpifenjcibgnknlbnj";
          crxPath = ./fixture.crx;
          version = "1.0.0";
        }
        {
          id = "clngdbkpkpeebahjckkjfobafhncgmne";
          installationMode = "force_installed";
        } # Stylus, test only.
      ];
    });
    bootstrap = contrast.wrap ({lib, ...}: {
      extensions = lib.mkOverride 40 ["nngceckbapebfimnlniiiahkandclblb"];
    });
    restoreCheck = package.wrap ({config, ...}: {
      profileDirectory = "Profile 1";
      preferences.homepage = "https://explicit.invalid/";
      sync.files.bravePreferences.sources = [
        {
          path = "\${HOME}/snapshot/Default/Preferences";
          format = "json";
        }
        {
          path = config.constructFiles.bravePreferences.path;
          format = "json";
        }
      ];
    });
  in {
    checks.brave-wrapper-isolation =
      pkgs.runCommand "brave-isolation-check" {
        PYTHONPATH = "${./.}";
        nativeBuildInputs = [(pkgs.python3.withPackages (p: [p.websocket-client]))];
        passthru = {inherit contrast bootstrap;};
      } ''
        python3 ${./isolation.py} ${lib.getExe package} ${lib.getExe contrast} ${lib.getExe bootstrap} ${lib.getExe pkgs.brave}
        touch "$out"
      '';
    checks.brave-wrapper-preferences =
      pkgs.runCommand "brave-policy-check" {
        nativeBuildInputs = [(pkgs.python3.withPackages (p: [p.websocket-client]))];
      } ''
        python3 ${./preferences.py} ${lib.getExe package} \
          ${snapshotCheck}/bin/brave-snapshot ${lib.getExe restoreCheck}
        touch "$out"
      '';
  };
}
