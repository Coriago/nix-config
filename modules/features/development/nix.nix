{inputs, ...}: {
  # NixOS
  flake.modules.nixos.development = {
    pkgs,
    config,
    ...
  }: {
    imports = [
      inputs.nixos-cli.nixosModules.nixos-cli
    ];
    programs.nixos-cli = {
      enable = true;
      settings = {
        differ.tool = "command";
        differ.command = ["nvd" "diff"];
        apply.use_nom = true;
        config_location = "/home/${config.hostmeta.username}/.config/nix-config";
        apply.reexec_as_root = true;
      };
      option-cache.exclude = ["wrappers"];
    };
    environment.systemPackages = with pkgs; [
      nixd
      statix
      alejandra
      nvd
      nix-diff
      nix-inspect
      nix-output-monitor
    ];
  };
}
