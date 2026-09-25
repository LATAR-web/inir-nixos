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

1. **Pre-flight** — verifica NixOS, `git`, `nix`, `sudo`, espacio libre en `/nix` (el primer rebuild necesita ~10GB), y corre `nix flake check`.
2. **Detección del entorno** — resuelve el usuario/home real (incluso con `sudo`); lee hostname, zona horaria, locale, teclado, GPU y tipo de VM.
3. **Elección de display manager** — recomienda `greetd` en VMs/NVIDIA (GDM puede ocultar la sesión niri); elección interactiva.
4. **Limpieza de systemd** — elimina el archivo `~/.config/systemd/user/inir.service` creado por `inir doctor` (que sobreescribe el servicio de NixOS) y otros obsoletos.
5. **Adaptación de `/etc/nixos`** — respalda e instala `/modules`; conserva tu `configuration.nix`; inyecta `./modules` en `imports`; asegura `allowUnfree` (ver abajo); **adapta la config a tu máquina** (ver abajo).
6. **Despliegue de Niri + Pipeline Material You** — instala `~/.config/niri/config.kdl` (adaptando el teclado) y activa `niri-sync-colors`.
7. **Rebuild** — `nixos-rebuild switch --flake`, log en `/tmp/inir-nixos-install-<fecha>.log`; si falla, muestra instrucciones de rollback.

### Opciones del instalador

| Opción | Descripción |
|---|---|
| `./install.sh` | Interactivo, con confirmaciones. |
| `./install.sh --yes` (`-y`) | No interactivo: responde "sí" a todo. |
| `./install.sh --dry-run` | Simula todo, no cambia nada. **Recomendado en la primera corrida.** |
| `./install.sh --skip-rebuild` | Instala archivos/servicios pero omite `nixos-rebuild switch`. |
| `./install.sh --no-ai` | Omite la revisión opcional de configuración con IA. |
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

### 🔓 Software privativo (unfree)

El instalador busca `allowUnfree` en `configuration.nix`, `flake.nix` y `modules/*.nix`. Si falta (o está en `false` explícito), ofrece activarlo — sin eso, los drivers NVIDIA, Steam, VS Code y demás fallan al evaluarse. Si lo rechazas, solo avisa y continúa.

### 🖥️ Adaptación automática a tu máquina

Tras instalar los módulos, el instalador **escribe ajustes específicos de tu hardware en `/etc/nixos/configuration.nix`** — cada bloque se salta si el ajuste ya existe, se confirma individualmente y se respalda antes:

| Detectado | Inyectado en `configuration.nix` |
|---|---|
| Display manager elegido (paso 3) | `programs.inir.desktop.displayManager = "greetd";` cuando eliges greetd |
| Teclado no-US | `services.xserver.xkb.layout` + `console.keyMap` |
| GPU NVIDIA | `services.xserver.videoDrivers`, `hardware.nvidia` (modesetting, módulo open) y variables de sesión Wayland (`GBM_BACKEND`, `__GLX_VENDOR_LIBRARY_NAME`, …) |
| CPU Intel/AMD | `hardware.cpu.{intel,amd}.updateMicrocode` + `hardware.enableRedistributableFirmware` |
| VM (KVM/QEMU, VirtualBox, VMware) | Guest agent: `services.qemuGuest.enable`, `virtualisation.{virtualbox,vmware}.guest.enable` |
| Usuario sin grupos `i2c`/`video` | Declara al usuario con grupos listos para brillo (se salta con un aviso si ya está declarado en tu config) |

Los ajustes que ya defines tú nunca se duplican ni se sobreescriben.

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

### 🔑 niri no aparece en la pantalla de login (GDM)

GDM puede **ocultar sesiones Wayland** (incluida niri) en tres casos conocidos: VMs sin aceleración 3D, algunas combinaciones de driver NVIDIA, o estado obsoleto de AccountsService que recuerda una sesión vieja. El instalador detecta VM/NVIDIA y recomienda **greetd** precisamente por esto.

Si niri no aparece tras reiniciar, haz una de estas dos cosas:

- Cambia el display manager en `/etc/nixos/configuration.nix`:
  ```nix
  programs.inir.desktop.displayManager = "greetd";   # o "gdm"
  ```
  y luego `sudo nixos-rebuild switch --flake /etc/nixos#nixos`. tuigreet siempre lista todas las sesiones instaladas (elige niri con F3).
- O limpia el estado obsoleto de AccountsService: `sudo rm -f /var/lib/AccountsService/users/*` y reinicia.

### 🤖 Revisión de configuración con IA (opcional)

El instalador ofrece una revisión opcional y de solo lectura mediante un CLI de IA. Revisa la configuración resultante en busca de conflictos y problemas de tu máquina (GPU, VM, display manager) y solo *imprime sugerencias* — nunca edita archivos. Sáltalo con `--no-ai`.

¿No tienes ningún CLI de IA instalado? **No pasa nada:** descarga `@anthropic-ai/claude-code` al vuelo con `npx` (solo queda en caché — nada se instala permanentemente). En un NixOS puro sin npm, usa un `nix shell nixpkgs#nodejs` efímero. Reutiliza tu login/API key de Claude si ya lo tienes; si nunca se autenticó, la revisión se salta sin drama.

### 🧩 Módulos no destructivos

`modules/default.nix` **auto-importa cada archivo `.nix`** en `/etc/nixos/modules` (excepto `inir-deps.nix`, que es una función). El instalador solo sobreescribe los archivos de iNiR (`audio.nix`, `desktop.nix`, `fonts.nix`, `inir-deps.nix`, `inir.nix`, `runtime.nix`, `default.nix`) — tus módulos propios (`packages.nix`, `printing.nix`, …) se conservan y se importan automáticamente, sin editar listas de imports.

### 🖼️ Aviso del renderizador de fondos

En Ajustes → Renderizador de fondos aparece *"awww is the default backend, but the 'awww' / 'awww-daemon' binaries were not found in PATH"* si falta `awww`. Viene incluido en [`modules/inir-deps.nix`](modules/inir-deps.nix); tras un `nixos-rebuild switch` el aviso desaparece y iNiR usa transiciones de fondo aceleradas por hardware. Hasta entonces usa silenciosamente el renderizador interno — nada se rompe.

### 📸 Solución de problemas con capturas

- Las capturas de región se guardan en el **directorio XDG de imágenes** (`~/Imágenes/Screenshots` con locale en español, `~/Pictures/Screenshots` en inglés) — no en una ruta fija. La acción *Copiar* de la barra escribe ahí y también copia la imagen al portapapeles.
- La barra de captura **recuerda la última acción** (`rememberSnipChoice` en `~/.config/illogical-impulse/config.json`). Si el menú abre pero "no pasa nada", probablemente quedó seleccionada *Búsqueda de imagen* (acción `2`), que sube el recorte a un servicio externo en lugar de guardarlo localmente. Se reinicia con:
  ```bash
  jq '.regionSelector.lastAction = 0 | .regionSelector.lastMode = 0' \
    ~/.config/illogical-impulse/config.json > /tmp/c.json && mv /tmp/c.json \
    ~/.config/illogical-impulse/config.json
  ```
- `magick` (ImageMagick) es necesario para recortar la captura de grim; está incluido en [`modules/inir-deps.nix`](modules/inir-deps.nix). Si recortaste tus dependencias, vuelve a añadir `imagemagick` o el recorte fallará silenciosamente.
- <kbd>Print</kbd> / <kbd>Ctrl</kbd>+<kbd>Print</kbd> / <kbd>Alt</kbd>+<kbd>Print</kbd> usan la UI de capturas integrada de niri y siempre guardan en `$XDG_PICTURES_DIR/Screenshots`.

---

## ✅ Verificación Post-Instalación

```bash
bash scripts/verify-setup.sh
```

También puedes probar el módulo `materialyoucolor` de Python directamente:
```bash
python3 -c "import materialyoucolor; print('materialyoucolor funciona correctamente!')"
```

Comprueba herramientas CLI, la importación del módulo Python `materialyoucolor`, el estado de los servicios, y además: `allowUnfree` activado, la sesión Wayland de niri registrada, y espacio libre en `/nix`.

---

## 🔄 Actualizaciones

```bash
cd /etc/nixos && nix flake update
sudo nixos-rebuild switch --flake /etc/nixos
systemctl --user restart inir.service
```

Rollback: `sudo nixos-rebuild switch --rollback`

> [!NOTE]
> Los respaldos del instalador viven en `/tmp/inir-nixos-backups-<fecha>/` y se **borran al reiniciar**. Cópialos a un sitio permanente si quieres conservarlos:
> ```bash
> cp -r /tmp/inir-nixos-backups-<fecha> ~/inir-nixos-backups
> ```

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
