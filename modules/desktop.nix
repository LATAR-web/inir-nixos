{ config, pkgs, lib, ... }:
let
  cfg = config.programs.inir.desktop;
in
{
  options.programs.inir.desktop = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable a graphical login screen (display manager) out of the box.";
    };

    displayManager = lib.mkOption {
      type = lib.types.enum [ "gdm" "greetd" ];
      default = "gdm";
      example = "greetd";
      description = ''
        Which display manager to use for the login screen:

        - "gdm" (default): GNOME Display Manager. Full-featured, remembers users,
          but it can HIDE Wayland sessions on some systems — VMs without 3D
          acceleration, some NVIDIA setups, or when AccountsService remembers an
          old X11 session. If niri does not appear in GDM's session list,
          switch to "greetd".

        - "greetd": minimal Wayland-first greeter (tuigreet). It always lists
          every installed Wayland session (including niri), has no GNOME
          dependency, and works in VMs without 3D acceleration.
      '';
    };

    enableGnomeFallback = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Install and enable the GNOME desktop environment as an emergency fallback
        session (GDM only). Disabled by default to avoid downloading gigabytes of
        unused GNOME packages.
      '';
    };
  };

  config = lib.mkMerge [
    (lib.mkIf (cfg.enable && cfg.displayManager == "gdm") {
      # Display manager (login screen)
      # Niri registers its own Wayland session automatically once programs.niri.enable is true.
      services.xserver.enable = lib.mkDefault true;
      services.displayManager.gdm.enable = lib.mkDefault true;
      services.desktopManager.gnome.enable = lib.mkDefault cfg.enableGnomeFallback;

      # Keyboard layout (defaults to user's existing settings if already defined)
      services.xserver.xkb = {
        layout = lib.mkDefault "us";
        variant = lib.mkDefault "";
      };
    })

    (lib.mkIf (cfg.enable && cfg.displayManager == "greetd") {
      # Wayland-first greeter: tuigreet lists every session in wayland-sessions,
      # so niri always shows up (fixes "niri missing from GDM", common in VMs).
      services.greetd = {
        enable = lib.mkDefault true;
        settings = {
          default_session = {
            command = "${pkgs.greetd.tuigreet}/bin/tuigreet --time --remember --remember-session --asterisks";
            user = "greeter";
          };
        };
      };

      # Never run two display managers at once.
      services.displayManager.gdm.enable = lib.mkForce false;

      # Console keyboard fallback for TTY sessions
      console.keyMap = lib.mkDefault "us";
    })
  ];
}
