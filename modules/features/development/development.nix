{
  flake.modules.nixos.development = {config, ...}: {
    virtualisation.docker = {
      enable = true;
      autoPrune.enable = true;
    };
    users.users.${config.vars.username}.extraGroups = ["docker"];

    programs.direnv = {
      enable = true;
      enableZshIntegration = true;
      nix-direnv.enable = true;
    };
  };

  flake.modules.homeManager.development = {pkgs, ...}: {
    home.packages = with pkgs; [
      python311

      # Node.js for VS Code extension development
      nodejs_22
      nodePackages.typescript
      nodePackages.typescript-language-server

      # VS Code extension tooling
      vsce # VS Code Extension Manager
      opencode
    ];
  };
}
