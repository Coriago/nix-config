{
  # NixOS
  flake.modules.nixos.base = {config, ...}: {
    services.openssh = {
      enable = true;
      settings.PermitRootLogin = "yes";
    };
    users.users.root.openssh.authorizedKeys.keys = [
      config.vars.sshPublicKey
    ];
    users.users.${config.vars.username}.openssh.authorizedKeys.keys = [
      config.vars.sshPublicKey
    ];
    programs.ssh.startAgent = true;
  };

  # Home Manager
  flake.modules.homeManager.base = {pkgs, ...}: {
    programs.ssh = {
      enable = true;
      enableDefaultConfig = false;
      matchBlocks = {
        "*" = {
          addKeysToAgent = "yes";
        };
      };
    };
    systemd.user.services.ssh-add = {
      Unit = {
        Description = "Add SSH keys to agent on login";
        After = ["graphical-session.target"];
      };
      Service = {
        Type = "simple";
        ExecStart = "${pkgs.openssh}/bin/ssh-add";
        # RemainAfterExit = true;
      };
      Install = {
        WantedBy = ["graphical-session.target"];
      };
    };
  };
}
