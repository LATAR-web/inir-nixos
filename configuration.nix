{ config, pkgs, inir, ... }:

{
  imports = [
    inir.nixosModules.inir
    ./hardware-configuration.nix
    ./modules/desktop.nix
    ./modules/audio.nix
    ./modules/printing.nix
    ./modules/packages.nix
    ./modules/runtime.nix
  ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = "nixos";
  networking.networkmanager.enable = true;

  time.timeZone = "America/Mexico_City";
  i18n.defaultLocale = "es_MX.UTF-8";

  programs.dconf.enable = true;
  networking.firewall.allowedTCPPorts = [ 53317 ];
  networking.firewall.allowedUDPPorts = [ 53317 ];

  systemd.tmpfiles.rules = [
    "L+ /bin/cat - - - - ${pkgs.coreutils}/bin/cat"
  ];

  users.users."ltar" = {
    isNormalUser = true;
    description = "LTAR";
    extraGroups = [ "networkmanager" "wheel" ];
    packages = with pkgs; [ ];
  };

  systemd.user.services.inir.environment.INIR_VENV = "%h/.local/share/inir/venv";

  # Puts these binaries on inir.service's PATH — extraPackages alone only
  # wires up Qt plugin paths / QML imports, it does NOT add executables
  # to the service's $PATH (that PATH is a short fixed list). Scripts the
  # shell spawns internally (python3, uv, jq, etc.) need this instead.
  systemd.user.services.inir.path = with pkgs; [
    (python3.withPackages (ps: with ps; [ ps.pip ps.materialyoucolor ps.pillow ps.evdev ps.numpy ]))
    uv
    cliphist
    jq
    ddcutil
  ];

  programs.inir = {
    enable = true;
    service.compositor = "niri";
    extraPackages = import ./modules/inir-deps.nix { inherit pkgs; };
  };

  programs.niri.enable = true;
  system.stateVersion = "26.05";
}
