# OpenRGB configuration for NixOS
{
  flake.modules.nixos.vmtest = {
    config,
    pkgs,
    ...
  }: {
    # 1. Enable libvirtd and QEMU features
    virtualisation.libvirtd = {
      enable = true;
      qemu = {
        package = pkgs.qemu_kvm;
        runAsRoot = true;
        swtpm.enable = true; # Required for Windows 11 TPM
      };
    };
    programs.virt-manager.enable = true;

    # 2. Enable Spice USB redirection (to pass your NZXT board to the VM)
    virtualisation.spiceUSBRedirection.enable = true;

    # 3. Required packages
    environment.systemPackages = with pkgs; [
      virt-manager # The GUI for managing VMs
      virt-viewer # For high-performance console access
      spice-gtk # Required for USB redirection in the GUI
      dnsmasq
    ];

    # 4. Add your user to the libvirtd group
    users.users.${config.vars.username}.extraGroups = ["libvirtd" "kvm"];
  };

  # reg add HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\OOBE /v BypassNRO /t REG_DWORD /d 1 /f
}
