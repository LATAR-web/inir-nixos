{ config, pkgs, lib, ... }:
let
  cfg = config.programs.inir.desktop;
in
{
  options.programs.inir.desktop = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable GDM display manager so you have a graphical login screen out of the box.";
    };

    enableGnomeFallback = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Install and enable GNOME desktop environment as an emergency fallback session.
        Disabled by default to avoid downloading gigabytes of unused GNOME packages.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
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
  };
}
