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

  # Base programs & permissions
  nixpkgs.config.allowUnfree = true;
  programs.dconf.enable = true;
  programs.niri.enable = true;

  # Standard paths & icon theme compatibility
  systemd.tmpfiles.rules = [
    "L+ /bin/cat - - - - ${pkgs.coreutils}/bin/cat"
    "d /usr/share 0755 root root -"
    "L+ /usr/share/icons - - - - /run/current-system/sw/share/icons"
  ];

  # Primary User (automatically configured by install.sh)
  users.users."YOUR_USERNAME" = {
    isNormalUser = true;
    description = "Primary User";
    extraGroups = [ "networkmanager" "wheel" "video" "i2c" ];
    packages = with pkgs; [ ];
  };

  system.stateVersion = "26.05";
}
