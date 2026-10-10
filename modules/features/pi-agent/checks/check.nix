{
  perSystem = {
    pkgs,
    lib,
    self',
    ...
  }: let
    feature = (self'.packages.mypi.eval {}).config;
    # Only the sandbox check disables Chromium's nested namespace sandbox.
    testBrowserServer = feature.chromeDevtools.server.wrap {
      appendFlag = ["--chrome-arg=--no-sandbox"];
    };
    testWrapper = self'.packages.mypi.wrap ({lib, ...}: {
      chromeDevtools.server = lib.mkForce testBrowserServer;
      snapshot.autoMerge = false;
    });
    standaloneBrowserCheck = testBrowserServer.wrap {
      flags."--config" = ../config/chrome-devtools.json;
    };
  in {
    checks.mypi =
      pkgs.runCommand "mypi-smoke-test" {
        nativeBuildInputs = [pkgs.python3];
      } ''
        export HOME="$TMPDIR/home"
        mkdir -p "$HOME"
        ${pkgs.nodejs}/bin/node ${./context7-check.mjs} ${../config/context7.ts}
        python ${./check.py} ${lib.getExe testWrapper} ${./check.ts}
        python ${./browser-check.py} ${lib.getExe' standaloneBrowserCheck "chrome-devtools-mcp"}
        touch "$out"
      '';
  };
}
