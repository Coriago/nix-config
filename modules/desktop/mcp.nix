{inputs, ...}: {
  flake.modules.homeManager.desktop-extras = {...}: {
    imports = [
      inputs.mcp-servers-nix.homeManagerModules.default
    ];

    mcp-servers.programs = {
      playwright.enable = true;
    };

    programs.mcp.enable = true;
  };
}
