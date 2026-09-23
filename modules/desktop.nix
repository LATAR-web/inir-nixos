{ config, pkgs, ... }:
{
  # Display manager (login screen) + GNOME as a fallback session.
  # Niri itself is a separate session GDM lists automatically once
  # programs.niri.enable is on — this file's job is just to make sure
  # there IS a graphical login screen at all, and a safe fallback
  # session exists if niri/iNiR ever fails to start.
  services.xserver.enable = true;
  services.xserver.xkb = {
    layout = "latam";   # CHANGE ME: your keyboard layout (e.g. "us")
    variant = "";
  };

  services.displayManager.gdm.enable = true;
  services.desktopManager.gnome.enable = true;

  console.keyMap = "la-latin1";   # CHANGE ME: match your xkb layout above
}
