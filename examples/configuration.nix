# Ejemplo de configuración para /etc/nixos/configuration.nix
# Integrando iNiR Desktop Shell sobre Niri Wayland
{ config, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    # Si usas flakes, importa el módulo desde inputs: inir-nixos.nixosModules.default
    # Si copiaste la carpeta modules/: ./modules
  ];

  # Bootloader (ajusta según tu sistema UEFI o BIOS)
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Red y Hostname
  networking.hostName = "nixos";
  networking.networkmanager.enable = true;

  # Zona horaria e idioma
  time.timeZone = "America/Mexico_City";
  i18n.defaultLocale = "es_MX.UTF-8";

  # Paquetes privativos (necesario para drivers NVIDIA, Steam, etc.)
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
      autoDeployConfig = true; # Despliega automáticamente ~/.config/niri y ~/.config/alacritty
      defaultTerminal = "alacritty";
    };

    # Audio PipeWire + WirePlumber con integración pactl/playerctl
    audio.enable = true;

    # Pantalla de login (display manager): "gdm" o "greetd" (tuigreet)
    desktop = {
      enable = true;
      displayManager = "gdm"; # Usa "greetd" si estás en una VM sin aceleración 3D
      enableGnomeFallback = false;
    };

    # Mascota Kira (compañero interactivo de escritorio y widgets)
    # mascot.enable = true;
  };

  # Usuario principal
  # NOTA: 'video' e 'i2c' son requeridos para brillo y ddcutil
  users.users."TU_USUARIO" = {
    isNormalUser = true;
    extraGroups = [ "networkmanager" "wheel" "video" "i2c" ];
  };

  system.stateVersion = "24.11";
}
