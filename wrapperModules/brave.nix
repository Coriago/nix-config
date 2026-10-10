{locallib, ...}: {
  flake.wrappers.brave = {
    config,
    lib,
    pkgs,
    wlib,
    ...
  }: let
    externalExtensions = builtins.filter (extension: extension.installationMode == "external") config.extensions;
    managedExtensions = builtins.filter (extension: extension.installationMode != "external") config.extensions;
    extensionPolicies = lib.listToAttrs (map (extension: {
        name = extension.id;
        value = {
          installation_mode = extension.installationMode;
          update_url =
            if extension.crxPath != null
            then throw "Brave managed extensions require an update URL, not crxPath"
            else extension.updateUrl;
        };
      })
      managedExtensions);
  in {
    imports = [locallib.sync-snap locallib.directory-mappings];

    options = {
      userDataDir = lib.mkOption {
        type = lib.types.str;
        default = "\${XDG_CONFIG_HOME}/BraveSoftware/Brave-Browser";
        description = ''
          Writable browser data directory, shared by all profiles. Supports
          sync-snap's HOME/XDG placeholders. Set this option rather than passing a different
          --user-data-dir. Sync defaults to this directory, keeping preferences,
          policies, and external extension manifests with the selected browser data.
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
              description = "Extension ID from the Chrome Web Store or packaged CRX public key.";
            };
            crxPath = lib.mkOption {
              type = lib.types.nullOr lib.types.path;
              default = null;
              description = "Prebuilt CRX file, as in Home Manager's Chromium module. Requires version and external installation mode; installed without downloading the initial package.";
            };
            version = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default = null;
              description = "Version from the prebuilt CRX manifest; required when crxPath is set.";
            };
            installationMode = lib.mkOption {
              type = lib.types.enum ["external" "normal_installed" "force_installed"];
              default = "external";
              description = "external uses the Home Manager manifest and respects UI removal. normal_installed uses managed policy and allows disabling; force_installed requires the extension and prevents removal or disabling.";
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
          External mode respects removal in the UI. Managed modes use Chromium
          ExtensionSettings in a process-local policy file; other mandatory host
          policy files remain visible. Brave may show a managed-browser indicator.
        '';
      };
    };

    config = {
      package = lib.mkDefault pkgs.brave;
      sync.enable = lib.mkDefault true;
      sync.defaultDir = lib.mkDefault config.userDataDir;
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
      directoryMappingParentDirs =
        lib.optionals (config.recommendedPolicies != {} || managedExtensions != []) [
          "/etc"
          "/etc/brave"
          "/etc/brave/policies"
        ]
        ++ lib.optional (managedExtensions != []) "/etc/brave/policies/managed";
      constructFiles =
        {
          bravePreferences = {
            relPath = "${config.profileDirectory}/Preferences";
            content = builtins.toJSON config.preferences;
          };
        }
        // lib.optionalAttrs (config.recommendedPolicies != {}) {
          braveRecommendedPolicies = {
            relPath = "brave-policies/recommended/wrapper.json";
            content = builtins.toJSON config.recommendedPolicies;
          };
        }
        // lib.optionalAttrs (managedExtensions != []) {
          braveManagedExtensions = {
            relPath = "brave-policies/managed/nix-wrapper-extensions.json";
            content = builtins.toJSON {ExtensionSettings = extensionPolicies;};
          };
        }
        // lib.listToAttrs (map (extension: {
            name = "braveExtension-${extension.id}";
            value = {
              relPath = "brave-extensions/${extension.id}.json";
              content =
                if extension.crxPath != null && (extension.version == null || extension.installationMode != "external")
                then throw "Brave prebuilt extensions require version and installationMode = external"
                else
                  builtins.toJSON (
                    if extension.crxPath != null
                    then {
                      external_crx = extension.crxPath;
                      external_version = extension.version;
                    }
                    else {external_update_url = extension.updateUrl;}
                  );
            };
          })
          externalExtensions);
      sync.files =
        {
          bravePreferences = {
            format = lib.mkDefault "json";
            # Browser-owned files must not be merged while a profile is running.
            policy = lib.mkDefault "seed";
          };
        }
        // lib.optionalAttrs (managedExtensions != []) {
          # Do not retain removed required IDs. Omit the sync entry without its source.
          braveManagedExtensions.policy = lib.mkDefault "replace";
        }
        // lib.listToAttrs (map (extension: {
            name = "braveExtension-${extension.id}";
            value.policy = lib.mkDefault "replace";
          })
          externalExtensions);
      snapshot.files =
        {
          bravePreferences = {
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
          braveManagedExtensions.enable = false;
        }
        // lib.listToAttrs (map (extension: {
            name = "braveExtension-${extension.id}";
            value.enable = false;
          })
          externalExtensions);
      directoryMappings =
        lib.optional (config.recommendedPolicies != {}) {
          source =
            if config.sync.enable
            then builtins.dirOf config.sync.files.braveRecommendedPolicies.path
            else "${placeholder "out"}/brave-policies/recommended";
          target = "/etc/brave/policies/recommended";
        }
        ++ lib.optional (managedExtensions != []) {
          source =
            if config.sync.enable
            then config.sync.files.braveManagedExtensions.path
            else "${placeholder "out"}/brave-policies/managed/nix-wrapper-extensions.json";
          target = "/etc/brave/policies/managed/nix-wrapper-extensions.json";
          directory = false;
        }
        ++ lib.optional (externalExtensions != []) {
          # Expose only declared IDs, even if old synced manifests remain on disk.
          source = "${placeholder "out"}/brave-extensions";
          target = "${config.userDataDir}/External Extensions";
        }
        ++ lib.optionals config.sync.enable (map (extension: {
            source = config.sync.files."braveExtension-${extension.id}".path;
            target = "${config.userDataDir}/External Extensions/${extension.id}.json";
            directory = false;
          })
          externalExtensions);
    };
  };
}
