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

  # =========================================================================
  # Ajustes de iNiR Desktop Shell (Declarativo para NixOS)
  # =========================================================================
  programs.inir = {
    enable = true;

    # Sincronización automática de colores Material You (Niri focus-ring, Alacritty, GTK)
    colorSync.enable = true;

    # Herramienta de grabación de pantalla de alto rendimiento con audio
    screenRecording.enable = true;

    # Soporte I2C y DDC/CI para control de brillo de monitores externos
    hardware.brightnessControl = true;

    # Compositor Wayland Niri con configuración modular lista para usar
    niri = {
      enable = true;
      autoDeployConfig = true;
      defaultTerminal = "alacritty";
    };

    # Audio PipeWire + WirePlumber con integración pactl/playerctl
    audio.enable = true;

    # Pantalla de login (display manager): "gdm" o "greetd" (tuigreet)
    desktop = {
      enable = true;
      displayManager = "gdm";
      enableGnomeFallback = false;
    };

    # Mascota Kira (compañero interactivo de escritorio y widgets)
    # mascot.enable = true;
  };

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

  # Primary User
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
