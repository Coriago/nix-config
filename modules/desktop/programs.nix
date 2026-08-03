# Main file for enabling programs and applications in the desktop environment
{inputs, ...}: {
  # NixOS
  flake.modules.nixos.desktop-extras = {
    pkgs,
    config,
    ...
  }: {
    # LLM Tools
    nixpkgs.overlays = [
      inputs.llm-agents.overlays.default
    ];
    environment.systemPackages = with pkgs; [
      usbutils
      gcc
      qemu
      disko
      rpi-imager
      xhost
      llm-agents.oh-my-opencode
      llm-agents.opencode
      gh
      ghostty
      tree-sitter
      vim
      neovim
      go
      ripgrep
      cargo
      rustc
      rustfmt
      clippy
      rust-analyzer

      bottles
      ty
      pyright
      nixd
      alejandra
      just
      just-lsp
      age
      disko
      sops
      bitwarden-cli
      bws
      unrar
      hugo
      nodejs
      publii
      xclicker
    ];
    programs = {
      usbtop.enable = true;
    };
    services.flatpak.packages = [
      "com.stremio.Stremio" # Stremio
    ];
    # Tailscale
    services.tailscale.enable = true;
    networking.nameservers = ["100.100.100.100" "1.1.1.1"];
    networking.search = ["li-taipan.ts.net"];
  };

  # Home Manager
  flake.modules.homeManager.desktop-extras = {pkgs, ...}: {
    programs = {
      kubecolor.enable = true;
      k9s.enable = true;
      vscode.enable = true;
      discord.enable = true;
      nushell.enable = true;
      btop.enable = true;
      firefox.enable = true;
    };

    home.sessionVariables = {
      BROWSER = "brave";
      EDITOR = "code -w";
    };

    home.packages = with pkgs; [
      brave
      vlc
      realvnc-vnc-viewer
      orca-slicer
      krita
      element-desktop

      # Dev stuff
      kubectl
      devenv

      python312Packages.python-kasa
    ];

    # imports = [
    #   inputs.lazyvim.homeManagerModules.default
    # ];

    # programs.lazyvim = {
    #   enable = true;
    #   extras = {
    #     lang.nix.enable = true;
    #     lang.python = {
    #       enable = true;
    #       installDependencies = true; # Install ruff
    #       installRuntimeDependencies = true; # Install python3
    #     };
    #     lang.go = {
    #       enable = true;
    #       installDependencies = true; # Install gopls, gofumpt, etc.
    #       installRuntimeDependencies = true; # Install go compiler
    #     };
    #   };

    #   extraPackages = with pkgs; [
    #     nixd # Nix LSP
    #     alejandra # Nix formatter
    #   ];

    #   # Only needed for languages not covered by LazyVim extras
    #   treesitterParsers = with pkgs.vimPlugins.nvim-treesitter-parsers; [
    #     wgsl # WebGPU Shading Language
    #     templ # Go templ files
    #   ];
    # };

    # programs.zsh. = "";
  };
}
