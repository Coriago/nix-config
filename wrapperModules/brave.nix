{locallib, ...}: {
  flake.wrappers.brave = {
    config,
    lib,
    pkgs,
    wlib,
    ...
  }: {
    imports = [locallib.sync-snap locallib.directory-mappings];

    options = {
      userDataDir = lib.mkOption {
        type = lib.types.str;
        default = "\${XDG_CONFIG_HOME}/BraveSoftware/Brave-Browser";
        description = ''
          Writable browser data directory, shared by all profiles. Supports
          sync-snap's HOME/XDG placeholders. Set this option rather than passing a different
          --user-data-dir, so external extension discovery uses the same directory.
        '';
      };
      profileDirectory = lib.mkOption {
        type = lib.types.strMatching "[A-Za-z0-9 _-]+";
        default = "Default";
        example = "Profile 1";
        description = "Selected profile directory beneath userDataDir; used for launch, preference seeding, and snapshots.";
      };
      preferences = lib.mkOption {
        type = wlib.types.structuredValueWith {typeName = "JSON";};
        default = {};
        description = ''
          Native profile preferences, seeded together with a reviewed snapshot
          only when Preferences is missing. Existing profiles are never rewritten
          by default. Prefer recommendedPolicies for ongoing editable defaults.
          Protected preferences, including search-engine integrity data, are not
          portable; snapshots retain only a small allowlist of documented settings.
        '';
      };
      recommendedPolicies = lib.mkOption {
        type = wlib.types.structuredValueWith {typeName = "JSON";};
        default = {};
        description = ''
          Brave/Chromium recommended policies. Users can override these defaults
          in browser settings. The generated directory is presented at Brave's
          fixed Linux policy path only inside the wrapped process; other host
          recommended policy files are hidden there. Mandatory host policies still
          apply. Brave may show "Managed by your organization".
        '';
      };
      extensions = lib.mkOption {
        default = [];
        type = lib.types.listOf (lib.types.coercedTo lib.types.str (id: {inherit id;}) (lib.types.submodule {
          options = {
            id = lib.mkOption {
              type = lib.types.strMatching "[a-p]{32}";
              description = "Extension ID from the Chrome Web Store.";
            };
            updateUrl = lib.mkOption {
              type = lib.types.str;
              default = "https://clients2.google.com/service/update2/crx";
              description = "URL of the extension update manifest.";
            };
          };
        }));
        description = ''
          External extensions, using Home Manager's Brave manifest format.
          Brave downloads and updates them at runtime. These manifests replace
          the visible External Extensions directory only inside the wrapper;
          GUI-installed extensions and their writable storage remain in the profile.
          Include other externally managed extensions here as well: hiding their
          manifests can cause Brave to uninstall them.
          Removing an extension in the UI blocks automatic reinstallation.
        '';
      };
    };

    config = {
      package = lib.mkDefault pkgs.brave;
      sync.enable = lib.mkDefault true;
      flags."--profile-directory" = {
        data = config.profileDirectory;
        sep = "=";
      };
      flags."--user-data-dir" = {
        data = config.userDataDir;
        sep = "=";
        esc-fn = wlib.escapeShellArgWithEnv;
      };
      # Binding a missing /etc target cannot create it in root-owned host dirs.
      # Recreate only its parents, retaining unrelated /etc and managed policies.
      directoryMappingParentDirs = lib.optionals (config.recommendedPolicies != {}) [
        "/etc"
        "/etc/brave"
        "/etc/brave/policies"
      ];
      constructFiles =
        {
          bravePreferences = {
            relPath = "brave-preferences.json";
            content = builtins.toJSON config.preferences;
          };
        }
        // lib.optionalAttrs (config.recommendedPolicies != {}) {
          braveRecommendedPolicies = {
            relPath = "brave-policies/recommended/wrapper.json";
            content = builtins.toJSON config.recommendedPolicies;
          };
        }
        // lib.listToAttrs (map (extension: {
            name = "braveExtension-${extension.id}";
            value = {
              relPath = "brave-extensions/${extension.id}.json";
              content = builtins.toJSON {external_update_url = extension.updateUrl;};
            };
          })
          config.extensions);
      sync.files.bravePreferences = {
        destinationDir = lib.mkDefault config.userDataDir;
        destinationPath = lib.mkOverride 900 "${config.profileDirectory}/Preferences";
        format = lib.mkDefault "json";
        # Browser-owned files must not be merged while a profile is running.
        policy = lib.mkDefault "seed";
      };
      snapshot.files =
        {
          bravePreferences = {
            destinationPath = lib.mkOverride 900 "Preferences.json";
            # A whitelist drops private/stateful objects even as new keys appear.
            # Only retain documented scalar UI and password-manager preferences.
            transform = lib.mkDefault [
              ''
                . as $input |
                reduce [
                  {path: ["homepage"], type: "string"},
                  {path: ["homepage_is_newtabpage"], type: "boolean"},
                  {path: ["browser", "show_home_button"], type: "boolean"},
                  {path: ["bookmark_bar", "show_on_all_tabs"], type: "boolean"},
                  {path: ["credentials_enable_service"], type: "boolean"},
                  {path: ["credentials_enable_autosignin"], type: "boolean"}
                ][] as $field ({};
                  ($input | getpath($field.path)) as $value |
                  if ($value | type) == $field.type
                  then setpath($field.path; $value) else . end)
              ''
            ];
            pruneValueContains = lib.mkDefault ["/nix/store/" "^file:"];
          };
          # These are declared wiring, not browser-owned preferences.
          braveRecommendedPolicies.enable = false;
        }
        // lib.listToAttrs (map (extension: {
            name = "braveExtension-${extension.id}";
            value.enable = false;
          })
          config.extensions);
      directoryMappings =
        lib.optional (config.recommendedPolicies != {}) {
          source =
            if config.sync.enable
            then builtins.dirOf config.sync.files.braveRecommendedPolicies.path
            else "${placeholder "out"}/brave-policies/recommended";
          target = "/etc/brave/policies/recommended";
        }
        ++ lib.optional (config.extensions != []) {
          source =
            if config.sync.enable
            then "${config.sync.defaultDir}/brave-extensions"
            else "${placeholder "out"}/brave-extensions";
          target = "${config.userDataDir}/External Extensions";
        };
    };
  };
}
