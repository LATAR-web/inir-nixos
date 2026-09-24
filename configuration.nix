{ config, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ./modules
  ];

  # Bootloader
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Networking
  networking.hostName = "nixos";
  networking.networkmanager.enable = true;
  networking.firewall.allowedTCPPorts = [ 53317 ];
  networking.firewall.allowedUDPPorts = [ 53317 ];

  # Locale & Timezone
  time.timeZone = "America/Mexico_City";
  i18n.defaultLocale = "es_MX.UTF-8";

  # Nixpkgs configuration
  nixpkgs.config.allowUnfree = true;

  # Optional iNiR module customizations:
  # programs.inir.audio.enable = true;               # Enabled by default (PipeWire)
  # programs.inir.desktop.enable = true;             # Enabled by default (GDM)
  # programs.inir.desktop.enableGnomeFallback = false; # Set true only if you want GNOME installed as fallback

  # Virtualization: QEMU / KVM, GNOME Boxes & Virt-Manager (Optional)
  # virtualisation.libvirtd = {
  #   enable = true;
  #   qemu = {
  #     package = pkgs.qemu_kvm;
  #     runAsRoot = true;
  #     swtpm.enable = true;
  #     verbatimConfig = ''
  #       max_core = 0
  #     '';
  #   };
  # };
  # virtualisation.spiceUSBRedirection.enable = true;
  # programs.virt-manager.enable = true;
  # security.pam.loginLimits = [
  #   { domain = "*"; item = "core"; type = "-"; value = "unlimited"; }
  # ];
  # environment.systemPackages = with pkgs; [
  #   gnome-boxes # Simple & modern VM manager
  #   qemu        # QEMU utilities
  # ];

  # Primary User (automatically configured by install.sh)
  # NOTE: 'video' and 'i2c' groups are required for monitor brightness controls (ddcutil)
  # NOTE: 'libvirtd' and 'kvm' groups are required for hardware-accelerated VMs without root
  users.users."YOUR_USERNAME" = {
    isNormalUser = true;
    description = "Primary User";
    extraGroups = [ "networkmanager" "wheel" "video" "i2c" "libvirtd" "kvm" ];
    packages = with pkgs; [ ];
  };

  system.stateVersion = "26.05";
}
