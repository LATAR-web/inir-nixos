{ config, pkgs, lib, inir, ... }:

let
  inirDeps = import ./inir-deps.nix { inherit pkgs; };
  versionJsonFile = pkgs.writeText "inir-version.json" ((builtins.toJSON {
    version = "2.31.0";
    commit = "9574fa424c0d1008e927454e933a7fbe292f9fb2";
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
  hardware.i2c.enable = true;

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
