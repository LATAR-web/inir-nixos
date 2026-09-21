{ config, pkgs, ... }:
{
  nixpkgs.config.allowUnfree = true;

  environment.systemPackages = with pkgs; [
    git
    fastfetch
    vscode
    brave
    alacritty
    jq
    python3
    uv
  ];
}
