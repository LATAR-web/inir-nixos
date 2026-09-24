<div align="center">

# ❄️ iNiR on NixOS

<p>
  <b><a href="README.md">English</a></b> |
  <b>Español</b>
</p>

[![Experimental](https://img.shields.io/badge/Estado-Experimental-orange?style=for-the-badge&logo=flattr&logoColor=white)](#-instalación-rápida)
[![NixOS](https://img.shields.io/badge/NixOS-unstable-5277C3?style=for-the-badge&logo=nixos&logoColor=white)](https://nixos.org)
[![Niri](https://img.shields.io/badge/Niri-wayland-88C0D0?style=for-the-badge&logo=wayland&logoColor=white)](https://github.com/YaLTeR/niri)
[![Flakes](https://img.shields.io/badge/Flakes-enabled-7EBAE4?style=for-the-badge)](https://nixos.wiki/wiki/Flakes)
[![iNiR](https://img.shields.io/badge/iNiR-shell-orange?style=for-the-badge)](https://github.com/snowarch/iNiR)
[![Material You](https://img.shields.io/badge/Theming-Material_You-green?style=for-the-badge)](https://github.com/snowarch/iNiR)

<img width="1920" height="1080" alt="iNiR on NixOS" src="https://github.com/user-attachments/assets/56163c9d-20f7-417b-a4a9-c5e9ee86c26e" />

### Guía modular reproducible e instalador automatizado para ejecutar [iNiR](https://github.com/snowarch/iNiR) sobre el compositor Wayland Niri en NixOS con Flakes.

</div>

---

## 🚀 Instalación Rápida

> [!CAUTION]
> **`install.sh` cambia tu sistema de NixOS Estable a Inestable (`nixos-unstable`)** — necesario porque iNiR/Niri/Qt6 requieren paquetes que solo están ahí. Si ya estás en unstable, no cambia nada.

> [!WARNING]
> Este proyecto es **experimental**. El instalador no es destructivo (hace respaldos con timestamp antes de cualquier cambio), pero es **recomendable** correr `--dry-run` primero, sobre todo en sistemas de producción.

```bash
git clone https://github.com/LATAR-web/inir-nixos.git
cd inir-nixos
chmod +x install.sh
./install.sh --dry-run   # recomendado primero: simula todo, no cambia nada
./install.sh             # luego corre de verdad
```

¿Prefieres hacerlo a mano? Ve a [Opción B — Instalación Manual](#opción-b--instalación-manual-paso-a-paso) más abajo.

---

## 📑 Tabla de Contenidos

- [¿Cómo funciona el instalador?](#-cómo-funciona-el-script-de-instalación-installsh)
  - [Opciones del instalador](#opciones-del-instalador)
  - [Instalación Manual](#opción-b--instalación-manual-paso-a-paso)
- [Adaptación a la configuración del usuario](#-adaptación-a-la-configuración-del-usuario)
- [Estructura del Repositorio](#-estructura-del-repositorio--qué-va-en-dónde)
- [Sincronización de Color (Material You ↔ Niri)](#-sincronización-de-color-niri--fondo-de-pantalla)
- [Atajos de Teclado de Niri](#-atajos-de-teclado-en-niri)
- [Verificación Post-Instalación](#-verificación-post-instalación)
- [Actualizaciones y Rollbacks](#-actualizaciones)
- [Solución de Problemas](#-problemas-conocidos-y-soluciones)

---

## 🛠️ ¿Cómo funciona el script de instalación (`install.sh`)?

Corre 7 fases, de forma reproducible y segura:

1. **Pre-flight** — verifica NixOS, `git`, `nix`, `sudo`, y corre `nix flake check`.
2. **Detección del entorno** — resuelve el usuario/home real (incluso con `sudo`); lee hostname, zona horaria, locale y teclado.
3. **Limpieza de systemd** — elimina el archivo `~/.config/systemd/user/inir.service` creado por `inir doctor` (que sobreescribe el servicio de NixOS) y otros obsoletos.
4. **Adaptación de `/etc/nixos`** — respalda e instala `/modules`; conserva tu `configuration.nix`; inyecta `./modules` en `imports`.
5. **Despliegue de Niri** — respalda e instala `~/.config/niri/config.kdl`, adaptando el teclado.
6. **Pipeline Material You** — instala y activa `niri-sync-colors`.
7. **Rebuild** — `nixos-rebuild switch --flake`, log en `/tmp/inir-nixos-install-<fecha>.log`.

### Opciones del instalador

| Opción | Descripción |
|---|---|
| `./install.sh` | Interactivo, con confirmaciones. |
| `./install.sh --yes` (`-y`) | No interactivo: responde "sí" a todo. |
| `./install.sh --dry-run` | Simula todo, no cambia nada. **Recomendado en la primera corrida.** |
| `./install.sh --skip-rebuild` | Instala archivos/servicios pero omite `nixos-rebuild switch`. |
| `./install.sh --check` | Corre `scripts/verify-setup.sh` y termina. |
| `./install.sh --help` (`-h`) | Muestra la ayuda. |

### Opción B — Instalación Manual Paso a Paso

1. `sudo cp -a modules/ /etc/nixos/modules/`
2. Agrega `./modules` a `imports` en `configuration.nix`; agrega `video`/`i2c` a los grupos de tu usuario.
3. En `flake.nix`, agrega la entrada `inir` y pásala por `specialArgs`:
   ```nix
   inputs.inir = {
     url = "github:snowarch/inir";
     inputs.nixpkgs.follows = "nixpkgs";
   };
   outputs = { self, nixpkgs, inir, ... }: {
     nixosConfigurations."your_hostname" = nixpkgs.lib.nixosSystem {
       specialArgs = { inherit inir; };
       modules = [ ./configuration.nix ];
     };
   };
   ```
4. `sudo nixos-rebuild switch --flake /etc/nixos`
5. Instala config de Niri y daemon de colores:
   ```bash
   mkdir -p ~/.config/niri ~/.local/bin ~/.config/systemd/user
   cp niri/config.kdl ~/.config/niri/config.kdl
   cp scripts/niri-sync-colors ~/.local/bin/ && chmod +x ~/.local/bin/niri-sync-colors
   cp systemd/niri-sync-colors.service ~/.config/systemd/user/
   systemctl --user daemon-reload && systemctl --user enable --now niri-sync-colors.service
   ```

---

## 🧩 Adaptación a la Configuración del Usuario

Basado en `lib.mkDefault`, así que nunca choca con tu configuración existente.

```nix
{
  imports = [ ./hardware-configuration.nix ./modules ];

  programs.inir.audio.enable = true;                  # Audio PipeWire (activado por defecto)
  programs.inir.desktop.enable = true;                 # Gestor de login GDM
  programs.inir.desktop.enableGnomeFallback = false;   # Fallback GNOME (desactivado por defecto)

  users.users.your_user.extraGroups = [ "wheel" "networkmanager" "video" "i2c" ]; # para brillo DDC/CI
}
```

---

## 🗺️ Estructura del Repositorio — Qué va en dónde

| En este repositorio | Destino en el sistema | Propósito |
|---|---|---|
| `configuration.nix` | `/etc/nixos/configuration.nix` | Configuración base |
| `flake.nix` | `/etc/nixos/flake.nix` | Flake que fija nixpkgs y la entrada de iNiR |
| `modules/` | `/etc/nixos/modules/` | Paquete iNiR, deps, fuentes, audio, escritorio, parches |
| `niri/config.kdl` | `~/.config/niri/config.kdl` | Atajos, layout y focus-ring de Niri |
| `scripts/niri-sync-colors` | `~/.local/bin/` | Actualiza el focus-ring de Niri en vivo |
| `systemd/niri-sync-colors.service` | `~/.config/systemd/user/` | Ejecuta `niri-sync-colors --watch` |
| `scripts/verify-setup.sh` | Ejecución local | Script de diagnóstico |
| `install.sh` | Ejecución local | Instalador automatizado |

---

## 🎨 Sincronización de Color (Niri ↔ Fondo de Pantalla)

iNiR genera colores Material You desde tu fondo de pantalla usando `matugen` y una cadena de Python (`materialyoucolor`, `pillow`, `numpy`, `evdev`). Al elegir un fondo (<kbd>Mod</kbd> + <kbd>W</kbd>), el daemon `niri-sync-colors` detecta la nueva paleta y ejecuta `niri-config.py` para actualizar los colores activo/inactivo del `focus-ring` en `~/.config/niri/config.kdl` en tiempo real.

Ejecútalo manual, o prueba el script de Python directamente:
```bash
niri-sync-colors

python3 ~/.config/quickshell/inir/scripts/niri-config.py set layout focus-ring.active-color "#a8c7fa"
```

---

## ⌨️ Atajos de Teclado en Niri

| Atajo | Acción |
|---|---|
| <kbd>Mod</kbd> + <kbd>Enter</kbd> | Abrir terminal |
| <kbd>Mod</kbd> + <kbd>W</kbd> | Selector de fondo de pantalla |
| <kbd>Mod</kbd> + <kbd>Espacio</kbd> | Vista general (Overview) |
| <kbd>Mod</kbd> + <kbd>V</kbd> | Historial del portapapeles |
| <kbd>Mod</kbd> + <kbd>,</kbd> | Ajustes de iNiR |
| <kbd>Mod</kbd> + <kbd>/</kbd> | Cheatsheet |
| <kbd>Mod</kbd> + <kbd>Shift</kbd> + <kbd>S</kbd> | Captura de región |
| <kbd>Mod</kbd> + <kbd>Shift</kbd> + <kbd>X</kbd> | OCR de región |
| <kbd>Mod</kbd> + <kbd>Alt</kbd> + <kbd>R</kbd>/<kbd>F</kbd>/<kbd>S</kbd> | Grabar región / pantalla completa / detener |
| <kbd>Mod</kbd> + <kbd>E</kbd> | Gestor de archivos |
| <kbd>Mod</kbd> + <kbd>B</kbd> | Navegador web |
| <kbd>Mod</kbd> + <kbd>Q</kbd> / <kbd>Shift</kbd>+<kbd>Q</kbd> | Cerrar ventana / salir de sesión |
| <kbd>Mod</kbd> + <kbd>F</kbd> | Pantalla completa |
| <kbd>Mod</kbd> + <kbd>1</kbd>–<kbd>5</kbd> | Ir / mover a espacio de trabajo 1–5 |

---

## ✅ Verificación Post-Instalación

```bash
bash scripts/verify-setup.sh
```

También puedes probar el módulo `materialyoucolor` de Python directamente:
```bash
python3 -c "import materialyoucolor; print('materialyoucolor funciona correctamente!')"
```

Comprueba herramientas CLI, la importación del módulo Python `materialyoucolor`, y el estado de los servicios.

---

## 🔄 Actualizaciones

```bash
cd /etc/nixos && nix flake update
sudo nixos-rebuild switch --flake /etc/nixos
systemctl --user restart inir.service
```

Rollback: `sudo nixos-rebuild switch --rollback`

---

## 🐛 Problemas Conocidos y Soluciones

| Problema | Solución |
|---|---|
| Archivo huérfano `~/.config/systemd/user/inir.service` | Sobreescribe el servicio de NixOS. Elimínalo — el instalador lo hace automáticamente. |
| Error por ruta ausente `/bin/cat` | Corregido vía `systemd.tmpfiles.rules` en `modules/inir.nix`. |
| Iconos ausentes en QuickShell | Solucionado con el parche `modules/patches/inir-icon-theme.patch`. |
| Falla el control de brillo (DDC/CI) | Requiere grupos `video`/`i2c` y `hardware.i2c.enable = true`. |

---

*Hecho con ❄️ para NixOS y Niri*
