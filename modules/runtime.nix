{ config, pkgs, lib, ... }:
{
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  programs.nix-ld = {
    enable = true;
    libraries = with pkgs; [
      stdenv.cc.cc.lib
      zlib
    ];
  };
  environment.localBinInPath = true;
  environment.variables.LD_LIBRARY_PATH = "/run/current-system/sw/share/nix-ld/lib";
  boot.kernelParams = [ "i915.enable_psr=0" ];

  environment.variables.QML2_IMPORT_PATH = lib.makeSearchPath "lib/qt-6/qml" [
    pkgs.kdePackages.qt5compat
    pkgs.kdePackages.kirigami
    pkgs.kdePackages.qtmultimedia
    pkgs.kdePackages.syntax-highlighting
  ];

  environment.variables.QT_PLUGIN_PATH = lib.makeSearchPath "lib/qt-6/plugins" [
    pkgs.kdePackages.qtmultimedia
    pkgs.kdePackages.qt5compat
    pkgs.kdePackages.plasma-integration
    pkgs.darkly
  ];
}
