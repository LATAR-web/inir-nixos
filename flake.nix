{
  description = "NixOS + Niri + iNiR reference setup";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    inir = {
      url = "github:snowarch/inir";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, inir, ... }:
    let
      system = "x86_64-linux";
      systemConfig = nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = { inherit inir; };
        modules = [ ./configuration.nix ];
      };
    in {
      nixosConfigurations.nixos = systemConfig;

      # Default configuration fallback
      nixosConfigurations.default = systemConfig;

      # Expose modules for use as a flake input
      nixosModules.default = ./modules;
      nixosModules.inir = ./modules/inir.nix;
    };
}
