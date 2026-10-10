{config, ...}: let
  local = config;
in {
  perSystem = {
    pkgs,
    lib,
    self',
    ...
  }: {
    packages.mybrave = local.flake.wrappers.brave.wrap {
      inherit pkgs;
      sync.defaultDir = "\${XDG_CONFIG_HOME}/syncbrave";
      snapshot.enable = true;
      preferences.credentials_enable_autosignin = false;
      extensions = ["nngceckbapebfimnlniiiahkandclblb"]; # Bitwarden
      recommendedPolicies = {
        # Bitwarden's default-manager permission still needs user confirmation.
        PasswordManagerEnabled = false;
        DefaultSearchProviderEnabled = true;
        DefaultSearchProviderName = "Google";
        DefaultSearchProviderKeyword = "google.com";
        DefaultSearchProviderSearchURL = "https://www.google.com/search?q={searchTerms}";
        HomepageLocation = "https://homepage.backyard-host.com/";
        HomepageIsNewTabPage = false;
        ShowHomeButton = true;
      };
    };
    apps.mybrave = {
      type = "app";
      program = lib.getExe self'.packages.mybrave;
    };
  };

  flake.modules.nixos.brave = {pkgs, ...}: {
    environment.systemPackages = [local.flake.packages.${pkgs.stdenv.hostPlatform.system}.mybrave];
  };
}
