{
  config,
  inputs,
  self,
  ...
}: let
  inherit (config.meta) localLLM;
in {
  flake.modules.nixos.development = {pkgs, ...}: {
    environment.systemPackages = [self.packages.${pkgs.stdenv.hostPlatform.system}.myneovim];
  };

  perSystem = {
    pkgs,
    lib,
    self',
    ...
  }: let
    # nixpkgs currently ships the v1-only release. Pin upstream's v2 branch
    # separately until a v2-compatible release reaches our nixpkgs revision.
    opencode-nvim-v2 = pkgs.vimUtils.buildVimPlugin {
      pname = "opencode.nvim";
      version = "unstable-2026-09-24";
      src = pkgs.fetchFromGitHub {
        owner = "nickjvandyke";
        repo = "opencode.nvim";
        rev = "06770e2e3618b82703e3e7af1f2d5dc67bde0002";
        hash = "sha256-cY56YBPNQsutfTBtOsMkJaLRvxjQM4mO61A5w9Q8HWs=";
      };
    };
  in {
    packages.myneovim = inputs.wrapper-modules.wrappers.neovim.wrap {
      inherit pkgs;
      settings.config_directory = ./neovim;
      # Keep state/cache separate from any Neovim already on the host.
      env.NVIM_APPNAME = "myneovim";
      info = {
        fallback_rustc = "${pkgs.rustc}/bin/rustc";
        fallback_rust_src = "${pkgs.rustPlatform.rustLibSrc}";
        opencode_command = lib.getExe' self'.packages.myopencode "opencode";
        ai_completion_endpoint = "${localLLM.baseURL}/chat/completions";
        ai_completion_model = localLLM.model;
      };

      hosts.python3.nvim-host.enable = false;
      hosts.node.nvim-host.enable = false;
      hosts.ruby.nvim-host.enable = false;

      # Preserve dev-shell tools, activated venvs, and rustup/asdf/mise shims.
      suffixVar = [
        {
          name = "editor-tools";
          data = [
            "PATH"
            ":"
            (lib.makeBinPath (with pkgs; [
              git
              lazygit
              curl
              self'.packages.myopencode
              ripgrep
              fd
              wl-clipboard
              xclip
              nix
              nixd
              alejandra
              lua-language-server
              stylua
              python3
              pyright
              ruff
              go
              gopls
              rustc
              cargo
              rust-analyzer
              rustfmt
              gcc
              nodejs
              typescript-language-server
              typescript
              prettierd
            ]))
          ];
        }
      ];

      # Nix supplies plugins and compiled parsers; nothing installs at startup.
      specs.kickstart = with pkgs.vimPlugins; [
        guess-indent-nvim
        gitsigns-nvim
        which-key-nvim
        tokyonight-nvim
        todo-comments-nvim
        mini-nvim
        oil-nvim
        snacks-nvim
        opencode-nvim-v2
        minuet-ai-nvim
        plenary-nvim
        telescope-nvim
        telescope-fzf-native-nvim
        telescope-ui-select-nvim
        nvim-lspconfig
        fidget-nvim
        conform-nvim
        blink-cmp
        luasnip
        friendly-snippets
        (nvim-treesitter.withPlugins (p:
          with p; [
            bash
            c
            css
            diff
            go
            gomod
            gosum
            html
            javascript
            json
            lua
            luadoc
            markdown
            markdown_inline
            nix
            python
            query
            rust
            toml
            tsx
            typescript
            vim
            vimdoc
            yaml
          ]))
      ];
    };

    apps.myneovim = {
      type = "app";
      program = lib.getExe' self'.packages.myneovim "nvim";
      meta.description = "Self-contained Kickstart Neovim with development language servers";
    };

    checks.myneovim = pkgs.runCommand "myneovim-smoke-test" {} ''
      export HOME="$TMPDIR/home"
      export XDG_CONFIG_HOME="$HOME/.config"
      export XDG_DATA_HOME="$HOME/.local/share"
      export XDG_STATE_HOME="$HOME/.local/state"
      export XDG_CACHE_HOME="$HOME/.cache"
      export GOPROXY=off CARGO_NET_OFFLINE=true
      mkdir -p "$HOME"
      ${lib.getExe' self'.packages.myneovim "nvim"} --headless \
        -c 'luafile ${./neovim-check.lua}'
      touch "$out"
    '';

    checks.myneovim-projects =
      pkgs.runCommand "myneovim-project-tooling-test" {
        TEST_UV = lib.getExe pkgs.uv;
        TEST_PYTHON = lib.getExe pkgs.python312;
        TEST_RUSTUP = lib.getExe pkgs.rustup;
        TEST_RUST_TOOLCHAIN = pkgs.symlinkJoin {
          name = "myneovim-test-rust-toolchain";
          paths = with pkgs; [rustc rustc.unwrapped cargo rustfmt rust-analyzer];
        };
        TEST_GO = lib.getExe pkgs.go;
        TEST_SHELL = lib.getExe pkgs.bash;
      } ''
        export HOME="$TMPDIR/home"
        export XDG_CONFIG_HOME="$HOME/.config"
        export XDG_DATA_HOME="$HOME/.local/share"
        export XDG_STATE_HOME="$HOME/.local/state"
        export XDG_CACHE_HOME="$HOME/.cache"
        export UV_OFFLINE=1 UV_PYTHON_DOWNLOADS=never
        export GOPROXY=off CARGO_NET_OFFLINE=true
        mkdir -p "$HOME/project-bin"
        # Check the wrapper itself preserves inherited tool precedence.
        ln -s "$TEST_PYTHON" "$HOME/project-bin/python3"
        export PATH="$HOME/project-bin:$PATH"
        ${lib.getExe' self'.packages.myneovim "nvim"} --headless \
          -c 'luafile ${./neovim-project-check.lua}'
        touch "$out"
      '';
  };
}
