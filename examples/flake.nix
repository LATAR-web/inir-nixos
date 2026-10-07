# Ejemplo de flake de sistema para tu NixOS (/etc/nixos/flake.nix)
{
  description = "Mi configuración de NixOS con iNiR y Niri";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    inir-nixos = {
      url = "github:LATAR-web/inir-nixos";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, inir-nixos, ... }: {
    nixosConfigurations."tu-hostname" = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        ./hardware-configuration.nix
        ./configuration.nix
        inir-nixos.nixosModules.default
      ];
    };
  };
}
