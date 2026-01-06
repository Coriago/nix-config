{
  flake.modules.homeManager.development = {pkgs, ...}: {
    home.packages = with pkgs; [
      python311
      rpi-imager
      kitty

      # Node.js for VS Code extension development
      nodejs_22
      nodePackages.typescript
      nodePackages.typescript-language-server

      # VS Code extension tooling
      vsce # VS Code Extension Manager
    ];
  };
}
