{ config, pkgs, inir, ... }:

{
  imports = [
    inir.nixosModules.inir
    ./hardware-configuration.nix   # generado por nixos-generate-config, NO copiar el de otra máquina
    ./modules/packages.nix
    ./modules/inir-deps.nix
  ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = "nixos";  # cambia esto si quieres otro nombre de host
  networking.networkmanager.enable = true;

  time.timeZone = "America/Mexico_City";   # ajusta a tu zona horaria
  i18n.defaultLocale = "es_MX.UTF-8";

  programs.dconf.enable = true;

  users.users."TU_USUARIO" = {
    isNormalUser = true;
    description = "TU_USUARIO";
    extraGroups = [ "networkmanager" "wheel" ];
  };

  # ─────────────────────────────────────────────────────────────
  # iNiR: venv de Python para el pipeline de colores Material You.
  # Apunta a una ruta estable fuera de ~/.local/state/quickshell/
  # (esa carpeta la puede limpiar Quickshell solo, borrando el venv).
  systemd.user.services.inir.environment.INIR_VENV = "%h/.local/share/inir/venv";

  # CRÍTICO: extraPackages por sí solo NO agrega binarios al $PATH que ve
  # inir.service — ese PATH es una lista corta y fija (solo trae inir,
  # coreutils, findutils, gnugrep, gnused, systemd). Sin este bloque,
  # cualquier script interno de iNiR que invoque python3/jq/uv/ddcutil/etc.
  # falla en silencio (verás "Process failed to start, likely because the
  # binary could not be found" en `inir logs`), y el theming automático
  # (colores desde wallpaper, iconos, hot corners, etc.) no funciona.
  systemd.user.services.inir.path = with pkgs; [
    python3
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
