{pkgs, ...}: let
  scriptContent = builtins.readFile ./switch-input.sh;
  # Remove the shebang line since it's not needed when executed as a shell script bin
  scriptWithoutShebang = builtins.replaceStrings ["#!/usr/bin/env bash\n"] [""] scriptContent;
  switch-input = pkgs.writeShellScriptBin "switch-input" scriptWithoutShebang;
in {
  home.packages = [
    switch-input
    pkgs.ddcutil
  ];
}
