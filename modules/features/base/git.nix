{config, ...}: let
  inherit (config) meta;
in {
  flake.modules.nixos.base = {...}: {
    programs.git.enable = true;
  };

  flake.modules.homeManager.base = {config, lib, pkgs, ...}: {
    programs.git = {
      enable = true;
      settings = {
        user = {
          name = config.hostmeta.username;
          email = meta.email;
        };
        pull.rebase = true;
      };
    };

    # Restore the declarative baseline on activation as a writable file.
    xdg.configFile."git/config".enable = false;
    home.activation.gitConfig = lib.hm.dag.entryAfter ["linkGeneration"] ''
      run ${pkgs.coreutils}/bin/install -Dm644 \
        ${lib.escapeShellArg (toString config.xdg.configFile."git/config".source)} \
        ${lib.escapeShellArg "${config.xdg.configHome}/git/config"}
    '';
  };
}
