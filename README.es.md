<div align="center">

# ❄️ iNiR on NixOS

<p>
  <b><a href="README.md">English</a></b> |
  <b>Español</b>
</p>

[![NixOS](https://img.shields.io/badge/NixOS-unstable-5277C3?style=flat-square&logo=nixos&logoColor=white)](https://nixos.org)
[![Niri](https://img.shields.io/badge/Niri-wayland-88C0D0?style=flat-square&logo=wayland&logoColor=white)](https://github.com/YaLTeR/niri)
[![Flakes](https://img.shields.io/badge/Flakes-enabled-7EBAE4?style=flat-square)](https://nixos.wiki/wiki/Flakes)
[![iNiR](https://img.shields.io/badge/iNiR-shell-orange?style=flat-square)](https://github.com/snowarch/iNiR)
[![Material You](https://img.shields.io/badge/Theming-Material_You-green?style=flat-square)](https://github.com/snowarch/iNiR)

<img width="1920" height="1080" alt="iNiR on NixOS" src="https://github.com/user-attachments/assets/56163c9d-20f7-417b-a4a9-c5e9ee86c26e" />

### Módulos reproducibles para ejecutar [iNiR](https://github.com/snowarch/iNiR) sobre el compositor Wayland Niri en NixOS con Flakes.

</div>

---

## 📑 Tabla de Contenidos

- [📦 Instalación Manual (Recomendada)](#-instalación-manual-recomendada)
- [⚡ Instalación Automatizada (`install.sh`)](#-instalación-automatizada-installsh)
- [⌨️ Atajos de Teclado](#️-atajos-de-teclado)
- [🎨 Sincronización de Color](#-sincronización-de-color-material-you)
- [🗺️ Estructura del Repositorio](#️-estructura-del-repositorio)
- [🐛 Solución de Problemas](#-solución-de-problemas)

---

## 📦 Instalación Manual (Recomendada)

Este es el método **predilecto** si ya tienes tu propia configuración de NixOS y deseas integrar iNiR de manera limpia y bajo tu control.

### 1. Copia los módulos a `/etc/nixos`
```bash
sudo cp -a modules/ /etc/nixos/modules/

# Si /etc/nixos está gestionado con git, debes añadir la carpeta (o Flakes la ignorará):
sudo git -C /etc/nixos add -A modules/
```

### 2. Configura `/etc/nixos/flake.nix`
Agrega el input `inir` y pásalo mediante `specialArgs`:

```nix
{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    inir = {
      url = "github:snowarch/inir";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, inir, ... }: {
    nixosConfigurations.<tu_hostname> = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      specialArgs = { inherit inir; };
      modules = [ ./configuration.nix ];
    };
  };
}
```

### 3. Integra en `/etc/nixos/configuration.nix`
Importa `./modules`, habilita software privativo y añade los grupos necesarios para brillo y hardware:

```nix
{
  imports = [
    ./hardware-configuration.nix
    ./modules # Carga iNiR, Niri, fuentes y servicios
  ];

  nixpkgs.config.allowUnfree = true;
  users.users.<tu_usuario>.extraGroups = [ "wheel" "networkmanager" "video" "i2c" ];

  # Extra opcional: Mascota Kira (compañero interactivo, widgets y animaciones)
  # programs.inir.mascot.enable = true;
}
```

### 4. Limpia posibles directorios residuales
Si anteriormente clonaste o creaste `~/.config/quickshell/inir` a mano, bloquerá el runtime empaquetado:
```bash
[[ -d ~/.config/quickshell/inir && ! -L ~/.config/quickshell/inir ]] && rm -rf ~/.config/quickshell/inir
```

### 5. Reconstruye el sistema
```bash
sudo nixos-rebuild switch --flake /etc/nixos#<tu_hostname>
```

### 6. Inicializa symlinks de usuario y dotfiles
> [!IMPORTANT]
> `nixos-rebuild` solo aplica reglas de sistema (`root`). Para generar los symlinks del runtime de iNiR (`~/.config/quickshell/inir` y `~/.local/bin/inir`), **debes ejecutar `systemd-tmpfiles --user --create`**:

```bash
# 1. Crear symlinks del runtime de usuario
systemd-tmpfiles --user --create

# 2. Desplegar configuraciones de Niri, Alacritty y sincronizador de color
mkdir -p ~/.config/niri ~/.config/alacritty ~/.local/bin ~/.config/systemd/user
cp niri/config.kdl ~/.config/niri/config.kdl
cp alacritty/alacritty.toml ~/.config/alacritty/alacritty.toml
cp scripts/niri-sync-colors ~/.local/bin/ && chmod +x ~/.local/bin/niri-sync-colors
cp scripts/record-screen ~/.local/bin/ && chmod +x ~/.local/bin/record-screen
cp systemd/niri-sync-colors.service ~/.config/systemd/user/

# 3. Iniciar sincronización de color inicial
~/.local/bin/niri-sync-colors
systemctl --user daemon-reload && systemctl --user enable --now niri-sync-colors.service
```

### 7. Inicia tu sesión
Cierra sesión y selecciona **Niri** en tu pantalla de login (GDM o greetd). `inir.service` se iniciará automáticamente.

Para comprobar que todo está listo:
```bash
bash scripts/verify-setup.sh
```

---

## ⚡ Instalación Automatizada (`install.sh`)

> [!CAUTION]
> ### ⚠️ ADVERTENCIA: SOLO PARA INSTALACIONES NUEVAS / LIMPIAS
> `install.sh` **reconstruye por completo tu sistema NixOS**:
> - Migra tu canal a `nixos-unstable`.
> - Reescribe o inyecta configuraciones en `/etc/nixos/configuration.nix` (controladores GPU, microcódigo, display manager).
> - Puede sobreescribir tus dotfiles en `~/.config/`.
> 
> **NO lo ejecutes en un sistema personal con configuraciones existentes que desees conservar.** Para sistemas existentes, utiliza siempre la [Instalación Manual](#-instalación-manual-recomendada).

Si estás en una instalación nueva de NixOS y deseas automatizar todo:

```bash
git clone https://github.com/LATAR-web/inir-nixos.git
cd inir-nixos
chmod +x install.sh

./install.sh --dry-run   # Simulación obligatoria: comprueba sin modificar nada
./install.sh             # Ejecución interactiva
```

### Opciones del script:
| Bandera | Descripción |
|---|---|
| `--dry-run` | Simula la instalación sin tocar archivos ni reconstruir. |
| `-y`, `--yes` | Modo no interactivo: asume "sí" a todas las confirmaciones. |
| `--skip-rebuild` | Despliega archivos y dotfiles pero omite `nixos-rebuild switch`. |
| `--check` | Ejecuta `scripts/verify-setup.sh` y termina. |

---

## ⌨️ Atajos de Teclado

| Atajo | Acción |
|---|---|
| <kbd>Mod</kbd> + <kbd>Enter</kbd> | Terminal (Alacritty) |
| <kbd>Mod</kbd> + <kbd>W</kbd> | Selector de fondo de pantalla (Material You) |
| <kbd>Mod</kbd> + <kbd>Espacio</kbd> / <kbd>Super</kbd> + <kbd>Tab</kbd> | Vista general de ventanas (Overview) |
| <kbd>Mod</kbd> + <kbd>V</kbd> | Historial del portapapeles |
| <kbd>Mod</kbd> + <kbd>,</kbd> | Ajustes de iNiR |
| <kbd>Mod</kbd> + <kbd>/</kbd> | Cheatsheet de atajos |
| <kbd>Mod</kbd> + <kbd>Shift</kbd> + <kbd>S</kbd> | Captura de pantalla de región |
| <kbd>Mod</kbd> + <kbd>Shift</kbd> + <kbd>X</kbd> | OCR de región (copia texto de imagen) |
| <kbd>Mod</kbd> + <kbd>Alt</kbd> + <kbd>R</kbd> / <kbd>S</kbd> | Grabar región / Detener grabación |
| <kbd>Mod</kbd> + <kbd>E</kbd> | Gestor de archivos (Nautilus) |
| <kbd>Mod</kbd> + <kbd>Q</kbd> / <kbd>Shift</kbd>+<kbd>Q</kbd> | Cerrar ventana / Salir de sesión |
| <kbd>Mod</kbd> + <kbd>1</kbd>–<kbd>5</kbd> | Ir a espacio de trabajo 1–5 |

---

## 🎨 Sincronización de Color (Material You)

Al seleccionar un nuevo fondo con <kbd>Mod</kbd> + <kbd>W</kbd>, `niri-sync-colors` extrae la paleta Material You automáticamente y actualiza en caliente:
- **Borde activo de Niri** (`focus-ring` en `~/.config/niri/config.kdl`).
- **Paleta de Alacritty** (`~/.config/alacritty/theme.toml`).
- **Acento GTK / GNOME** (`accent-color` de libadwaita).

---

## 🐾 Mascota Kira (Extra Opcional)

iNiR incluye a **Kira**, una mascota animada para tu escritorio que asoma por los bordes de la pantalla, reacciona a eventos (música, volumen, batería, actualizaciones) y ofrece minijuegos y widgets de fondo.

Para activarla en tu `/etc/nixos/configuration.nix`:
```nix
programs.inir.mascot.enable = true;
```

Tras reconstruir (`sudo nixos-rebuild switch`), puedes configurarla e interactuar con ella:
- **Ajustes gráficos:** <kbd>Mod</kbd> + <kbd>,</kbd> → **Mascota** (poses, tamaño, frecuencia de visita y widgets).
- **Comandos IPC:** `inir mascot poke`, `inir mascot romp` (modo caos), `inir mascot chase` (juego de atrapar), `inir mascot hideSeek` (escondite) o `inir mascot hide`.

---

## 🗺️ Estructura del Repositorio

| Archivo / Carpeta | Propósito |
|---|---|
| `modules/` | Módulos NixOS: paquete iNiR, dependencias, fuentes, audio y parches |
| `modules/mascot.nix` | Módulo extra: integración y paquete de arte de la mascota Kira |
| `niri/config.kdl` | Configuración de atajos, ventanas y focus-ring de Niri |
| `alacritty/alacritty.toml` | Configuración de terminal con soporte de temas dinámicos |
| `scripts/niri-sync-colors` | Demonio/script de sincronización de colores Material You |
| `scripts/record-screen` | Grabador de pantalla con audio |
| `scripts/verify-setup.sh` | Script de diagnóstico y verificación del entorno |
| `install.sh` | Instalador automatizado para sistemas nuevos |

---

## 🐛 Solución de Problemas

| Problema | Causa y Solución |
|---|---|
| `Unable to locate config-path helper` al correr `inir run` | **1)** No se inicializaron los enlaces de usuario: ejecuta `systemd-tmpfiles --user --create`.<br>**2)** Un directorio real tapa el runtime: ejecuta `rm -rf ~/.config/quickshell/inir && systemd-tmpfiles --user --create`. |
| Niri no aparece en la pantalla de login (GDM) | GDM a veces oculta sesiones Wayland en VMs o NVIDIA. Cambia a `programs.inir.desktop.displayManager = "greetd";` en tu configuración o limpia `sudo rm -f /var/lib/AccountsService/users/*`. |
| `allowUnfree` error al reconstruir | Añade `nixpkgs.config.allowUnfree = true;` en tu `configuration.nix`. |
| Control de brillo no responde | Asegúrate de tener los grupos `video` e `i2c` en tu usuario y `hardware.i2c.enable = true;`. |

---

<div align="center">
  <i>Hecho con ❄️ para NixOS y Niri</i>
</div>
