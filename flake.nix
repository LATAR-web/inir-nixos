{
  description = "NixOS + Niri + iNiR unified flake modules and packages";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    inir = {
      url = "github:LATAR-web/inir";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, inir, ... }:
    let
      supportedSystems = [ "x86_64-linux" "aarch64-linux" ];
      forAllSystems = nixpkgs.lib.genAttrs supportedSystems;
    in {
      # Paquetes individuales de iNiR y herramientas auxiliares expuestas por el flake
      packages = forAllSystems (system:
        let
          pkgs = import nixpkgs {
            inherit system;
            config.allowUnfree = true;
          };

          inirDeps = import ./modules/inir-deps.nix { inherit pkgs; };

          inirPatched = (pkgs.callPackage "${inir}/nix/package.nix" { inherit pkgs; }).overrideAttrs (old: {
            patches = (old.patches or [ ]) ++ [
              ./modules/patches/inir-icon-theme.patch
              ./modules/patches/inir-nixos-fixes.patch
            ];
          });

          mascotPackage = if builtins.pathExists "${inir}/nix/mascot-package.nix"
            then pkgs.callPackage "${inir}/nix/mascot-package.nix" { inherit pkgs; }
            else null;

          inirWithMascot = if mascotPackage != null
            then pkgs.symlinkJoin {
              name = "inir-with-mascot-${inirPatched.version or "2.32.0"}";
              paths = [ inirPatched mascotPackage ];
            }
            else inirPatched;

          niriSyncColors = pkgs.writeScriptBin "niri-sync-colors" (builtins.readFile ./scripts/niri-sync-colors);
          recordScreen = pkgs.writeScriptBin "record-screen" (builtins.readFile ./scripts/record-screen);

          inirDepsEnv = pkgs.buildEnv {
            name = "inir-deps";
            paths = inirDeps;
          };
        in {
          default = inirPatched;
          inir = inirPatched;
          inir-with-mascot = inirWithMascot;
          niri-sync-colors = niriSyncColors;
          record-screen = recordScreen;
          inir-deps = inirDepsEnv;
        }
      );

      # Overlays para extender nixpkgs con las herramientas de iNiR
      overlays.default = final: prev: {
        inir = self.packages.${final.system}.inir;
        inir-with-mascot = self.packages.${final.system}.inir-with-mascot;
        niri-sync-colors = self.packages.${final.system}.niri-sync-colors;
        record-screen = self.packages.${final.system}.record-screen;
        inir-deps = self.packages.${final.system}.inir-deps;
      };

      # Módulos NixOS exportados para integración manual en la configuración del usuario
      nixosModules = {
        default = { ... }: {
          imports = [
            inir.nixosModules.inir
            ./modules
          ];
          _module.args.inir = inir;
        };

        inir = { ... }: {
          imports = [
            inir.nixosModules.inir
            ./modules/inir.nix
          ];
          _module.args.inir = inir;
        };

        audio = ./modules/audio.nix;
        desktop = ./modules/desktop.nix;
        fonts = ./modules/fonts.nix;
        mascot = ./modules/mascot.nix;
        runtime = ./modules/runtime.nix;
      };
    };
}
