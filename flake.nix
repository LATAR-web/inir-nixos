{
  description = "NixOS + Niri + iNiR unified flake modules, packages, and apps";

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
      # =======================================================================
      # Packages
      # =======================================================================
      packages = forAllSystems (system:
        let
          pkgs = import nixpkgs {
            inherit system;
            config.allowUnfree = true;
          };

          inirDeps = import ./modules/inir-deps.nix { inherit pkgs; };

          inirPatched = ((pkgs.callPackage "${inir}/nix/package.nix" { inherit pkgs; }).overrideAttrs (old: {
            patches = (old.patches or [ ]) ++ [
              ./modules/patches/inir-icon-theme.patch
              ./modules/patches/inir-nixos-fixes.patch
            ];
            meta = (old.meta or { }) // {
              description = "Complete desktop shell for Niri built on Quickshell with Material You theming";
              homepage = "https://github.com/LATAR-web/inir-nixos";
              license = pkgs.lib.licenses.mit;
              mainProgram = "inir";
            };
          }));

          mascotPackage = if builtins.pathExists "${inir}/nix/mascot-package.nix"
            then pkgs.callPackage "${inir}/nix/mascot-package.nix" { inherit pkgs; }
            else pkgs.stdenvNoCC.mkDerivation {
              pname = "inir-mascot";
              version = "3.0";
              src = pkgs.fetchurl {
                url = "https://github.com/snowarch/inir-mascot/releases/download/v3/inir-mascot-pack.tar.gz";
                hash = "sha256-DCkWHOVa/7N9FlGD+XdVBuyXRnlWf+3Kv3Lp9f9aw5s=";
              };
              dontUnpack = true;
              installPhase = ''
                mkdir -p "$out/share/quickshell/inir/assets/images/mascot"
                tar xf "$src" -C "$out/share/quickshell/inir/assets/images/mascot/"
              '';
              meta = {
                description = "Official Kira animated desktop companion art pack for iNiR";
                homepage = "https://github.com/snowarch/inir-mascot";
                license = pkgs.lib.licenses.mit;
              };
            };

          inirWithMascot = if mascotPackage != null
            then pkgs.symlinkJoin {
              name = "inir-with-mascot-${inirPatched.version or "2.32.0"}";
              paths = [ inirPatched mascotPackage ];
              meta = (inirPatched.meta or { }) // {
                description = "iNiR desktop shell with official Kira desktop mascot art pack integrated";
                homepage = "https://github.com/LATAR-web/inir-nixos";
                license = pkgs.lib.licenses.mit;
                mainProgram = "inir";
              };
            }
            else inirPatched;

          niriSyncColors = pkgs.writeTextFile {
            name = "niri-sync-colors";
            executable = true;
            destination = "/bin/niri-sync-colors";
            text = builtins.readFile ./scripts/niri-sync-colors;
            meta = {
              description = "Dynamic Material You palette sync daemon for Niri focus rings, Alacritty, and GTK";
              homepage = "https://github.com/LATAR-web/inir-nixos";
              license = pkgs.lib.licenses.mit;
              mainProgram = "niri-sync-colors";
            };
          };

          recordScreen = pkgs.writeTextFile {
            name = "record-screen";
            executable = true;
            destination = "/bin/record-screen";
            text = builtins.readFile ./scripts/record-screen;
            meta = {
              description = "Hardware-accelerated Wayland screen recorder with audio capture via wf-recorder and pactl";
              homepage = "https://github.com/LATAR-web/inir-nixos";
              license = pkgs.lib.licenses.mit;
              mainProgram = "record-screen";
            };
          };

          verifySetup = pkgs.writeTextFile {
            name = "verify-setup";
            executable = true;
            destination = "/bin/verify-setup";
            text = builtins.readFile ./scripts/verify-setup.sh;
            meta = {
              description = "Automated diagnostic sanity-checker for iNiR, Niri, and NixOS configuration";
              homepage = "https://github.com/LATAR-web/inir-nixos";
              license = pkgs.lib.licenses.mit;
              mainProgram = "verify-setup";
            };
          };

          inirDepsEnv = pkgs.buildEnv {
            name = "inir-deps";
            paths = inirDeps;
            meta = {
              description = "Complete bundle of runtime dependencies for iNiR shell";
              homepage = "https://github.com/LATAR-web/inir-nixos";
              license = pkgs.lib.licenses.mit;
            };
          };
        in {
          default = inirPatched;
          inir = inirPatched;
          inir-with-mascot = inirWithMascot;
          inir-mascot = mascotPackage;
          niri-sync-colors = niriSyncColors;
          record-screen = recordScreen;
          verify-setup = verifySetup;
          inir-deps = inirDepsEnv;
        }
      );

      # =======================================================================
      # Apps (Run via: nix run github:LATAR-web/inir-nixos#<app>)
      # =======================================================================
      apps = forAllSystems (system: {
        default = {
          type = "app";
          program = "${self.packages.${system}.inir}/bin/inir";
        };
        inir = {
          type = "app";
          program = "${self.packages.${system}.inir}/bin/inir";
        };
        niri-sync-colors = {
          type = "app";
          program = "${self.packages.${system}.niri-sync-colors}/bin/niri-sync-colors";
        };
        record-screen = {
          type = "app";
          program = "${self.packages.${system}.record-screen}/bin/record-screen";
        };
        verify-setup = {
          type = "app";
          program = "${self.packages.${system}.verify-setup}/bin/verify-setup";
        };
      });

      # =======================================================================
      # Development Shell (Run via: nix develop)
      # =======================================================================
      devShells = forAllSystems (system:
        let
          pkgs = import nixpkgs {
            inherit system;
            config.allowUnfree = true;
          };
          inirDeps = import ./modules/inir-deps.nix { inherit pkgs; };
        in {
          default = pkgs.mkShell {
            name = "inir-dev-shell";
            packages = inirDeps ++ (with pkgs; [
              nixpkgs-fmt
              git
            ]);
            shellHook = ''
              echo "❄️ Welcome to the iNiR NixOS development environment!"
              echo "📦 Available packages: inir, niri, matugen, gowall, awww, python3, quickshell..."
            '';
          };
        }
      );

      # =======================================================================
      # Code Formatter (Run via: nix fmt)
      # =======================================================================
      formatter = forAllSystems (system: nixpkgs.legacyPackages.${system}.nixpkgs-fmt);

      # =======================================================================
      # Starter Templates (Run via: nix flake init -t github:LATAR-web/inir-nixos)
      # =======================================================================
      templates = {
        default = {
          path = ./templates/default;
          description = "Starter NixOS system configuration with iNiR desktop shell and Niri";
        };
        inir = {
          path = ./templates/default;
          description = "Starter NixOS system configuration with iNiR desktop shell and Niri";
        };
      };

      # =======================================================================
      # Overlays
      # =======================================================================
      overlays.default = final: prev: {
        inir = self.packages.${final.system}.inir;
        inir-with-mascot = self.packages.${final.system}.inir-with-mascot;
        inir-mascot = self.packages.${final.system}.inir-mascot;
        niri-sync-colors = self.packages.${final.system}.niri-sync-colors;
        record-screen = self.packages.${final.system}.record-screen;
        verify-setup = self.packages.${final.system}.verify-setup;
        inir-deps = self.packages.${final.system}.inir-deps;
      };

      # =======================================================================
      # NixOS Modules
      # =======================================================================
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

      # =======================================================================
      # Home Manager Modules
      # =======================================================================
      homeModules = {
        default = inir.homeModules.default;
        inir = inir.homeModules.inir;
      };
    };
}
