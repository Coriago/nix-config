{
  config,
  self,
  ...
}: let
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
      # Temporary pin until Brave returns to nixos-unstable.
      package = (import (builtins.fetchTarball {
        url = "https://github.com/NixOS/nixpkgs/archive/31ecbaca1bdefa45dffc409f0250bd8039ea0010.tar.gz";
        sha256 = "1lzqyss0pznfh3az0llsp4a7c8gqcyq8wf96fnl5cnh5b3lic6kn";
      }) {
        system = pkgs.stdenv.hostPlatform.system;
        config.allowUnfree = true;
      }).brave;
      snapshot.enable = true;
      # Expose web caret geometry to the keyboard overlay through AT-SPI.
      flags."--force-renderer-accessibility" = {
        data = "complete";
        sep = "=";
      };
      preferences.credentials_enable_autosignin = false;
      extensions = [
        {
          id = "nngceckbapebfimnlniiiahkandclblb"; # Bitwarden
          installationMode = "force_installed";
        }
        {
          id = "mnjggcdmjocbbbhaepdhchncahnbgone";
        }
        {
          id = "neebplgakaahbhdphmkckjjcegoiijjo";
        }
      ];
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
    environment.systemPackages = [self.packages.${pkgs.stdenv.hostPlatform.system}.mybrave];
    environment.sessionVariables.BROWSER = "brave";
    xdg.mime.defaultApplications = {
      "x-scheme-handler/http" = "brave-browser.desktop";
      "x-scheme-handler/https" = "brave-browser.desktop";
      "text/html" = "brave-browser.desktop";
      "application/xhtml+xml" = "brave-browser.desktop";
    };
  };
}
