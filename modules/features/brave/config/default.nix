# Personal Brave configuration. Edit this file; implementation lives in lib/wrappers/.
{config, ...}: {
  flake.wrappers.mybrave = {
    lib,
    pkgs,
    ...
  }: {
    imports = [config.flake.lib.wrapperModules.brave];

    homeManager.programs.brave = {
      extensions = lib.mkDefault ["nngceckbapebfimnlniiiahkandclblb"]; # Bitwarden
      # commandLineArgs = ["--no-default-browser-check"];
      # nativeMessagingHosts = [pkgs.keepassxc];
    };

    settings = {
      credentials_enable_service = lib.mkDefault false;
      credentials_enable_autosignin = lib.mkDefault false;
      # bookmark_bar.show_on_all_tabs = true;
    };
    configDir = lib.mkDefault ./recommended;
    managedPolicies.ExtensionSettings.nngceckbapebfimnlniiiahkandclblb.toolbar_pin = lib.mkDefault "default_pinned";
    snapshotSource = lib.mkDefault ./snapshot.json;

    syncSnap = {
      sync.preferences = {
        policy = lib.mkDefault "merge";
        trigger = lib.mkDefault "on-start";
      };
      snapshot.preferences = {
        prune_key_contains = builtins.fromJSON (builtins.readFile ./snapshot-pruning.json);
        prune_value_contains = ["/nix/store/" "^/(home|run/user|tmp)/" "^file://"];
        transform = [];
      };
    };
  };
}
