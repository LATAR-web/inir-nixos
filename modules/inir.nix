{ config, pkgs, lib, inir, ... }:

let
  inirDeps = import ./inir-deps.nix { inherit pkgs; };
  versionJsonFile = pkgs.writeText "inir-version.json" ((builtins.toJSON {
    version = inir.shortRev or "2.31.0";
    commit = inir.rev or "9574fa424c0d1008e927454e933a7fbe292f9fb2";
    installMode = "package-managed";
    updateStrategy = "package-manager";
    packageName = "inir";
    packageUpdateHint = "nixos-rebuild switch";
  }) + "\n");

  inirPatched = (pkgs.callPackage "${inir}/nix/package.nix" { inherit pkgs; }).overrideAttrs (old: {
    patches = (old.patches or [ ]) ++ [
      ./patches/inir-icon-theme.patch
      ./patches/inir-nixos-fixes.patch
    ];
  });
in
{
  imports = [
    inir.nixosModules.inir
  ];

  # Habilitar el módulo oficial de iNiR con detección de iconos corregida
  programs.inir = {
    enable = true;
    service.compositor = "niri";
    package = inirPatched;
    extraPackages = inirDeps;
  };

  # Paquetes disponibles globalmente en el sistema para herramientas y scripts de iNiR
  environment.systemPackages = inirDeps;

  # Control de hardware para brillo de monitores externos mediante ddcutil
  hardware.i2c.enable = lib.mkDefault true;

  # Rutas estándar FHS y temas de iconos para compatibilidad de scripts
  systemd.tmpfiles.rules = [
    "L+ /bin/cat - - - - ${pkgs.coreutils}/bin/cat"
    "d /usr/share 0755 root root -"
    "L+ /usr/share/icons - - - - /run/current-system/sw/share/icons"
  ];

  # Habilitar Niri y dconf por defecto
  programs.niri.enable = lib.mkDefault true;
  programs.dconf.enable = lib.mkDefault true;

  # Variables de entorno para el servicio user de systemd
  systemd.user.services.inir = {
    environment = {
      INIR_VENV = "%h/.local/state/quickshell/.venv";
    };
  };

  # Reglas de usuario para asegurar symlinks correctos y compatibilidad permanente de iconos
  systemd.user.tmpfiles.rules = [
    "L+ %h/.local/state/quickshell/.venv - - - - %h/.local/share/inir/venv"
    "L+ %h/.local/bin/inir - - - - /run/current-system/sw/bin/inir"
    "d %h/.config/inir 0755 - - -"
    "L+ %h/.config/inir/version.json - - - - ${versionJsonFile}"
    "d %h/.config/illogical-impulse 0755 - - -"
    "L+ %h/.config/illogical-impulse/version.json - - - - ${versionJsonFile}"
    "L+ %h/.icons - - - - %h/.local/share/icons"
    "L+ %h/.config/quickshell/inir - - - - /run/current-system/sw/share/quickshell/inir"
  ];
}
