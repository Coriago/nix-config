{
  # Common variables used across modules and hosts.
  # Each configuration should set these variables accordingly.
  flake.modules.generic.variables = {lib, ...}: let
    inherit (lib) mkOption types;
  in {
    options.vars = {
      username = mkOption {
        type = types.str;
        description = "The name of the primary user.";
      };

      email = mkOption {
        type = types.str;
        description = "The email address of the primary user.";
      };

      stateVersion = mkOption {
        type = types.str;
        description = "The state version of the system. Set this to the intial system version then DO NOT TOUCH.";
      };

      timeZone = mkOption {
        type = types.str;
        description = "The time zone for the system.";
        default = "America/New_York";
      };

      locale = mkOption {
        type = types.str;
        description = "The locale for the system.";
        default = "en_US.UTF-8";
      };

      keyLayout = mkOption {
        type = types.str;
        description = "The country keyboard layout.";
        default = "us";
      };

      wallpaper = mkOption {
        type = types.str;
        description = "Url to a wallpaper image.";
        default = "";
      };

      wallpaperHash = mkOption {
        type = types.str;
        description = "The sha256 hash of the wallpaper image.";
        default = "";
      };

      theme = mkOption {
        type = types.str;
        description = "The desktop theme to use. More can be found here: https://tinted-theming.github.io/tinted-gallery";
        default = "equilibrium-dark";
      };

      sshPublicKey = mkOption {
        type = types.str;
        description = "The SSH public key authorized for ssh.";
        default = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBYVacUQ/B11m2ycolJnoIKn4TS1alZKDbe1ssRnWZE2";
      };
    };
  };
}
