{inputs, ...}: {
  flake.modules.homeManager.desktop-extras = {...}: {
    imports = [
      inputs.mcp-servers-nix.homeManagerModules.default
    ];

    mcp-servers.programs = {
      # filesystem = {
      #   enable = true;
      #   args = ["/home/user/documents"];
      # };
      # context7.enable = true;
      playwright.enable = true;
    };

    # programs.mcp.enable = true;
  };
}
