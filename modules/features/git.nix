{
  config,
  meta,
  ...
}: {
  flake.modules.nixos.git = {hostmeta, ...}: {
    programs.git.enable = true;
    home-manager.users.${hostmeta.username}.imports = [
      config.flake.modules.homeManager.git
    ];
  };

  flake.modules.homeManager.git = {
    config,
    lib,
    pkgs,
    hostmeta,
    ...
  }: {
    programs.git = {
      enable = true;
      settings = {
        user = {
          name = hostmeta.username;
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
