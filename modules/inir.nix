{ config, pkgs, lib, inir ? null, ... }:

let
  inirFlake =
    if inir != null then inir
    else (builtins.fetchTarball {
      url = "https://github.com/LATAR-web/inir/archive/main.tar.gz";
    });

  inirNixosModule =
    if inirFlake ? nixosModules && inirFlake.nixosModules ? inir
    then inirFlake.nixosModules.inir
    else import "${inirFlake}/nix/nixos-module.nix";

  inirDeps = import ./inir-deps.nix { inherit pkgs; };
  pythonEnv = lib.findSingle
    (p: lib.hasPrefix "python3-" (p.name or "") && lib.hasSuffix "-env" (p.name or ""))
    (pkgs.python3.withPackages (ps: []))
    null
    inirDeps;

  niriSyncColors = pkgs.writeScriptBin "niri-sync-colors" (builtins.readFile ../scripts/niri-sync-colors);
  recordScreen = pkgs.writeScriptBin "record-screen" (builtins.readFile ../scripts/record-screen);

  versionJsonFile = pkgs.writeText "inir-version.json" ((builtins.toJSON {
    version = inirFlake.shortRev or inirFlake.dirtyShortRev or "2.33.0";
    commit = inirFlake.rev or inirFlake.dirtyRev or "48cdcecb";
    installMode = "package-managed";
    updateStrategy = "package-manager";
    packageName = "inir";
    packageUpdateHint = "nixos-rebuild switch";
  }) + "\n");

  inirPatched = (pkgs.callPackage "${inirFlake}/nix/package.nix" { inherit pkgs; }).overrideAttrs (old: {
    patches = (old.patches or [ ]) ++ [
      ./patches/inir-icon-theme.patch
      ./patches/inir-nixos-fixes.patch
    ];
  });

  mascotPackage = config.programs.inir.mascot.package or (
    if inirFlake != null && builtins.pathExists "${inirFlake}/nix/mascot-package.nix"
    then pkgs.callPackage "${inirFlake}/nix/mascot-package.nix" { inherit pkgs; }
    else null
  );

  inirPackage =
    if (config.programs.inir.mascot.enable or false) && mascotPackage != null
    then pkgs.symlinkJoin {
      name = "inir-with-mascot-${inirPatched.version or "2.33.0"}";
      paths = [ inirPatched mascotPackage ];
    }
    else inirPatched;

  cfg = config.programs.inir;
in
{
  options.programs.inir = {
    colorSync = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Habilitar el servicio de sincronización automática de colores Material You con Niri, Alacritty y GTK.";
      };
    };

    screenRecording = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Habilitar el script record-screen para grabación de pantalla Wayland con audio integrado.";
      };
    };

    hardware = {
      brightnessControl = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Habilitar soporte i2c y ddcutil para control de brillo en monitores externos.";
      };
    };

    niri = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Habilitar e integrar el compositor Wayland Niri para iNiR.";
      };
      autoDeployConfig = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Desplegar automáticamente la configuración modular de Niri y Alacritty si no existen en el directorio del usuario.";
      };
      defaultTerminal = lib.mkOption {
        type = lib.types.enum [ "alacritty" "kitty" "foot" ];
        default = "alacritty";
        description = "Terminal predeterminado a utilizar por el lanzador de Niri y iNiR.";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    # Habilitar el módulo oficial de iNiR con detección de iconos corregida y soporte para mascota
    programs.inir = {
      service.compositor = "niri";
      package = lib.mkDefault inirPackage;
      extraPackages = inirDeps;
    };

    # Paquetes disponibles globalmente en el sistema para herramientas y scripts de iNiR
    environment.systemPackages = inirDeps
      ++ (lib.optional cfg.colorSync.enable niriSyncColors)
      ++ (lib.optional cfg.screenRecording.enable recordScreen);

    # Variables de entorno globales para que cualquier shell o launcher localice el runtime
    environment.variables = {
      INIR_SYSTEM_RUNTIME_DIR = "/run/current-system/sw/share/quickshell/inir";
      INIR_FALLBACK_SYSTEM_RUNTIME_DIR = "/run/current-system/sw/share/quickshell/inir";
      INIR_VENV = "/run/current-system/sw/share/quickshell/.venv";
      ILLOGICAL_IMPULSE_VIRTUAL_ENV = "/run/current-system/sw/share/quickshell/.venv";
    };

    # Control de hardware para brillo de monitores externos mediante ddcutil
    hardware.i2c.enable = lib.mkDefault cfg.hardware.brightnessControl;

    # Rutas estándar FHS y temas de iconos para compatibilidad de scripts
    systemd.tmpfiles.rules = [
      "L+ /bin/cat - - - - ${pkgs.coreutils}/bin/cat"
      "d /usr/share 0755 root root -"
      "L+ /usr/share/icons - - - - /run/current-system/sw/share/icons"
      "L+ /usr/share/quickshell - - - - /run/current-system/sw/share/quickshell"
      "L+ /run/current-system/sw/share/quickshell/.venv - - - - ${pythonEnv}"
    ];

    # Habilitar Niri y dconf
    programs.niri.enable = lib.mkDefault cfg.niri.enable;
    programs.dconf.enable = lib.mkDefault true;

    # Elevación de privilegios gráfica (Polkit) para aplicaciones en Wayland
    security.polkit.enable = lib.mkDefault true;
    systemd.user.services.polkit-kde-authentication-agent-1 = {
      description = "polkit-kde-authentication-agent-1";
      wantedBy = [ "graphical-session.target" ];
      wants = [ "graphical-session.target" ];
      after = [ "graphical-session.target" ];
      serviceConfig = {
        Type = "simple";
        ExecStart = "${pkgs.kdePackages.polkit-kde-agent-1}/libexec/polkit-kde-authentication-agent-1";
        Restart = "on-failure";
        RestartSec = 1;
        TimeoutStopSec = 10;
      };
    };

    # Integración XDG Desktop Portal para captura de pantalla / WebRTC / diálogos en Niri
    xdg.portal = {
      enable = lib.mkDefault true;
      extraPortals = [
        pkgs.xdg-desktop-portal-gnome
        pkgs.xdg-desktop-portal-gtk
      ];
      config.niri.default = [ "gnome" "gtk" ];
    };

    # Soporte Bluetooth y daemon Blueman para el widget de iNiR
    hardware.bluetooth.enable = lib.mkDefault true;
    services.blueman.enable = lib.mkDefault true;

    # Demonio UPower para widget de batería y suspensión
    services.upower.enable = lib.mkDefault true;

    # Variables de entorno para el servicio user de systemd
    systemd.user.services.inir = {
      environment = {
        INIR_VENV = "%h/.local/state/quickshell/.venv";
        ILLOGICAL_IMPULSE_VIRTUAL_ENV = "%h/.local/state/quickshell/.venv";
      };
    };

    # Servicio de usuario para sincronización automática de colores con Niri / Alacritty / GTK
    systemd.user.services.niri-sync-colors = lib.mkIf cfg.colorSync.enable {
      description = "Sync Niri colors and iNiR wallpaper with generated theme data";
      wantedBy = [ "graphical-session.target" "default.target" ];
      after = [ "inir.service" ];
      serviceConfig = {
        Type = "simple";
        ExecStart = "${niriSyncColors}/bin/niri-sync-colors --watch";
        Restart = "on-failure";
        RestartSec = 5;
      };
    };

    # Reglas de usuario para asegurar symlinks correctos y compatibilidad permanente
    systemd.user.tmpfiles.rules = [
      "d %h/.local/bin 0755 - - -"
      "d %h/.local/state/quickshell 0755 - - -"
      "L+ %h/.local/state/quickshell/.venv - - - - ${pythonEnv}"
      "L+ %h/.local/bin/inir - - - - /run/current-system/sw/bin/inir"
      "L+ %h/.local/bin/niri-sync-colors - - - - ${niriSyncColors}/bin/niri-sync-colors"
      "L+ %h/.local/bin/record-screen - - - - ${recordScreen}/bin/record-screen"
      "L+ %h/.local/bin/pactl - - - - ${pkgs.pulseaudio}/bin/pactl"
      "d %h/.config/inir 0755 - - -"
      "L+ %h/.config/inir/version.json - - - - ${versionJsonFile}"
      "d %h/.config/illogical-impulse 0755 - - -"
      "L+ %h/.config/illogical-impulse/version.json - - - - ${versionJsonFile}"
      "d %h/.local/share/icons 0755 - - -"
      "L+ %h/.icons - - - - %h/.local/share/icons"
      "d %h/.config/quickshell 0755 - - -"
      "L+ %h/.config/quickshell/inir - - - - /run/current-system/sw/share/quickshell/inir"
    ] ++ lib.optionals cfg.niri.autoDeployConfig [
      "d %h/.config/niri 0755 - - -"
      "d %h/.config/niri/config.d 0755 - - -"
      "C+ %h/.config/niri/config.kdl - - - - ${../niri/config.kdl}"
      "C+ %h/.config/niri/config.d/10-input-and-cursor.kdl - - - - ${../niri/config.d/10-input-and-cursor.kdl}"
      "C+ %h/.config/niri/config.d/20-layout-and-overview.kdl - - - - ${../niri/config.d/20-layout-and-overview.kdl}"
      "C+ %h/.config/niri/config.d/30-window-rules.kdl - - - - ${../niri/config.d/30-window-rules.kdl}"
      "C+ %h/.config/niri/config.d/40-environment.kdl - - - - ${../niri/config.d/40-environment.kdl}"
      "C+ %h/.config/niri/config.d/50-startup.kdl - - - - ${../niri/config.d/50-startup.kdl}"
      "C+ %h/.config/niri/config.d/60-animations.kdl - - - - ${../niri/config.d/60-animations.kdl}"
      "C+ %h/.config/niri/config.d/70-binds.kdl - - - - ${../niri/config.d/70-binds.kdl}"
      "C+ %h/.config/niri/config.d/80-layer-rules.kdl - - - - ${../niri/config.d/80-layer-rules.kdl}"
      "C+ %h/.config/niri/config.d/90-user-extra.kdl - - - - ${../niri/config.d/90-user-extra.kdl}"
      "d %h/.config/alacritty 0755 - - -"
      "C+ %h/.config/alacritty/alacritty.toml - - - - ${../alacritty/alacritty.toml}"
    ];
  };
}
