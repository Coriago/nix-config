{
  flake.modules.nixos.linux-compat = {pkgs, ...}: {
    programs.nix-ld.enable = true;
    programs.nix-ld.libraries = with pkgs; [
      libglvnd
      libx11
      libxcursor
      libxext
      libxfixes
      libxi
      libxinerama
      libxrandr
      libxscrnsaver
      libxxf86vm
      wayland
      libxkbcommon
      alsa-lib
      libpulseaudio
      libsamplerate
    ];
  };
}
