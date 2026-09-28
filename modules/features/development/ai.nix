{
  inputs,
  self,
  ...
}: {
  flake.modules.nixos.development = {pkgs, ...}: {
    environment.systemPackages = [self.packages.${pkgs.stdenv.hostPlatform.system}.myopencode];
  };

  perSystem = {
    pkgs,
    lib,
    system,
    self',
    ...
  }: let
    memoryServer = pkgs.writeShellScriptBin "myopencode-memory" ''
      export MEMORY_FILE_PATH="''${MEMORY_FILE_PATH:-''${XDG_STATE_HOME:-$HOME/.local/state}/myopencode/memory.jsonl}"
      ${pkgs.coreutils}/bin/mkdir -p "$(${pkgs.coreutils}/bin/dirname "$MEMORY_FILE_PATH")"
      exec ${lib.getExe pkgs.mcp-server-memory} "$@"
    '';
  in {
    packages.myopencode = inputs.wrapper-modules.wrappers.opencode.wrap {
      inherit pkgs;
      package = inputs.llm-agents.packages.${system}.opencode2;
      exePath = "bin/opencode2";
      binName = "myopencode";
      settings = {
        "$schema" = "https://opencode.ai/config.json";
        autoupdate = false;
        mcp.memory = {
          type = "local";
          command = [(lib.getExe memoryServer)];
          enabled = true;
        };
      };
      # Keep tools from the invoking project environment ahead of fallbacks.
      suffixVar = [
        {
          name = "cli-tools";
          data = ["PATH" ":" (lib.makeBinPath [pkgs.git pkgs.ripgrep])];
        }
      ];
    };

    apps.myopencode = {
      type = "app";
      program = lib.getExe' self'.packages.myopencode "myopencode";
      meta.description = "OpenCode v2 with a packaged memory MCP server";
    };

    checks.myopencode =
      pkgs.runCommand "myopencode-smoke-test" {
        nativeBuildInputs = [pkgs.python3];
      } ''
        export HOME="$TMPDIR/home"
        export XDG_CONFIG_HOME="$HOME/.config"
        export XDG_DATA_HOME="$HOME/.local/share"
        export XDG_STATE_HOME="$HOME/.local/state"
        export XDG_CACHE_HOME="$HOME/.cache"
        mkdir -p "$HOME"
        python ${./opencode-check.py} ${self'.packages.myopencode}
        touch "$out"
      '';
  };
}
