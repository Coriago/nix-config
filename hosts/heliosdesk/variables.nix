{
  config,
  lib,
  ...
}: {
  imports = [
    # Choose your theme here:
    ../../themes/nixy.nix
  ];

  config.var = {
    hostname = "heliosdesk";
    username = "helios";
    configDirectory =
      "/home/"
      + config.var.username
      + "/nix-config"; # The path of the nixos configuration directory

    keyboardLayout = "us";

    location = "NewYork";
    timeZone = "America/New_York";
    defaultLocale = "en_US.UTF-8";
    extraLocale = "en_US.UTF-8";

    git = {
      username = "coriago";
      email = "gagemiller155@gmail.com";
    };

    autoUpgrade = false;
    autoGarbageCollector = true;
  };

  # Let this here
  options = {
    var = lib.mkOption {
      type = lib.types.attrs;
      default = {};
    };
  };
}
