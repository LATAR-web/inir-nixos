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

- [📦 Guía de Instalación](#-guía-de-instalación)
- [⌨️ Atajos de Teclado](#️-atajos-de-teclado)
- [🎨 Sincronización de Color](#-sincronización-de-color-material-you)
- [🐾 Mascota Kira (Fase de Pruebas)](#-mascota-kira-extra-opcional--fase-de-pruebas-)
- [🗺️ Estructura del Repositorio](#️-estructura-del-repositorio)
- [🐛 Solución de Problemas](#-solución-de-problemas)

---

## 📦 Guía de Instalación

Puedes integrar iNiR fácilmente en tu propia configuración manual de NixOS, ya sea utilizando **Nix Flakes** (recomendado) o mediante **Módulos locales**.

### Opción A: Usando Flakes (Recomendado)

En tu propio `/etc/nixos/flake.nix`:

```nix
{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    inir-nixos = {
      url = "github:LATAR-web/inir-nixos";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, inir-nixos, ... }: {
    nixosConfigurations.<tu_hostname> = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        ./hardware-configuration.nix
        ./configuration.nix
        inir-nixos.nixosModules.default
      ];
    };
  };
}
```

En tu `/etc/nixos/configuration.nix`:

```nix
{
  imports = [
    ./hardware-configuration.nix
  ];

  # Habilitar iNiR y todas sus dependencias declarativas
  programs.inir = {
    enable = true;
    colorSync.enable = true;
    screenRecording.enable = true;
    hardware.brightnessControl = true;
    niri = {
      enable = true;
      autoDeployConfig = true; # Despliega automáticamente ~/.config/niri y ~/.config/alacritty
      defaultTerminal = "alacritty";
    };
    audio.enable = true;
    desktop = {
      enable = true;
      displayManager = "gdm"; # o "greetd" si estás en una VM sin aceleración 3D
    };
  };

  nixpkgs.config.allowUnfree = true;
  users.users.<tu_usuario>.extraGroups = [ "wheel" "networkmanager" "video" "i2c" ];
}
```

### Opción B: Copiando los módulos a `/etc/nixos` (Manual sin Flake remoto)

```bash
sudo cp -a modules/ /etc/nixos/modules/

# Si /etc/nixos está gestionado con git:
sudo git -C /etc/nixos add -A modules/
```

Y en tu `/etc/nixos/configuration.nix` añade `imports = [ ./modules ];`.

---

### Paso Final: Reconstruir y desplegar dotfiles

1. **Reconstruye el sistema**:
   ```bash
   sudo nixos-rebuild switch --flake /etc/nixos#<tu_hostname>
   ```

2. **Inicializa los enlaces de usuario y dotfiles**:
   ```bash
   systemd-tmpfiles --user --create
   ```
   *(Esto crea automáticamente el entorno virtual de Python en `~/.local/state/quickshell/.venv`, los binarios en `~/.local/bin/`, la configuración modular de Niri en `~/.config/niri/config.d/` y Alacritty)*.

3. **Inicia sesión**:
   Selecciona la sesión **Niri** en tu pantalla de login. Ejecuta `bash scripts/verify-setup.sh` para comprobar que todos los servicios estén en verde (✅).

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

## 🐾 Mascota Kira (Extra Opcional · Fase de Pruebas 🧪)

> [!NOTE]
> **Fase experimental / pruebas:** La integración de la mascota Kira en NixOS se encuentra actualmente en **fase de pruebas**. Su comportamiento, poses y minijuegos están en evaluación activa.

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
