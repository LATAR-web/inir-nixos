{ config, pkgs, lib, ... }:
{
  # Display manager (login screen) + GNOME as a fallback session.
  # Niri itself is a separate session GDM lists automatically once
  # programs.niri.enable is on — this file's job is just to make sure
  # there IS a graphical login screen at all, and a safe fallback
  # session exists if niri/iNiR ever fails to start.
  services.xserver.enable = lib.mkDefault true;
  services.xserver.xkb = {
    layout = lib.mkDefault "latam";
    variant = lib.mkDefault "";
  };

  services.displayManager.gdm.enable = lib.mkDefault true;
  services.desktopManager.gnome.enable = lib.mkDefault true;

  console.keyMap = lib.mkDefault "la-latin1";
}
