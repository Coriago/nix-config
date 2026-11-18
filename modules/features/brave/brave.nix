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
