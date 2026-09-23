{ pkgs, ... }:
{
  fonts.packages = with pkgs; [
    nerd-fonts.jetbrains-mono
    roboto-flex
    google-fonts
    twitter-color-emoji
    material-symbols
    corefonts
  ];

  fonts.fontconfig.enable = true;
}
