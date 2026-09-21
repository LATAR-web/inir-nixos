# NixOS + Niri + iNiR — setup reproducible

Guía para instalar [iNiR](https://github.com/snowarch/iNiR) (shell basado en
Quickshell) sobre Niri, en NixOS con flakes, evitando los problemas que
`inir doctor` no sabe resolver en distros no-Arch.

## 0. Requisitos

- NixOS instalado, con flakes habilitados.
- Un usuario normal con `sudo`.

## 1. Clona este repo dentro de `/etc/nixos`

```bash
sudo mv /etc/nixos /etc/nixos.bak   # respalda lo que ya tenías
sudo git clone https://github.com/TU_USUARIO/inir-nixos-setup.git /etc/nixos
```

## 2. Genera TU hardware-configuration.nix

**No uses el de otra máquina.** Genera el tuyo:

```bash
sudo nixos-generate-config --show-hardware-config | sudo tee /etc/nixos/hardware-configuration.nix
```

## 3. Edita `configuration.nix`

Reemplaza `TU_USUARIO`, `networking.hostName`, `time.timeZone` por los tuyos.

## 4. Aplica

```bash
cd /etc/nixos
sudo nixos-rebuild switch --flake /etc/nixos#nixos
```

La primera vez va a tardar bastante — está compilando/descargando todo el
árbol de dependencias de iNiR (Qt, KDE frameworks, etc).

## 5. Verifica que iNiR arrancó

```bash
systemctl --user status inir.service
```

Debe decir `active (running)`.

## 6. Instala el sincronizador de colores para niri

Por defecto, iNiR sincroniza los colores del wallpaper con terminal, GTK,
editores, etc. — pero **no con niri mismo** (el compositor no sabe nada de
"temas"). Este script llena ese hueco:

```bash
mkdir -p ~/.local/bin ~/.config/systemd/user
cp scripts/niri-sync-colors ~/.local/bin/
chmod +x ~/.local/bin/niri-sync-colors
cp systemd/niri-sync-colors.service systemd/niri-sync-colors.path ~/.config/systemd/user/
systemctl --user daemon-reload
systemctl --user enable --now niri-sync-colors.path
```

## 7. Crea el venv de Python para el pipeline de colores

```bash
uv venv ~/.local/share/inir/venv --python 3
source ~/.local/share/inir/venv/bin/activate
uv pip install materialyoucolor pillow numpy
deactivate
systemctl --user restart inir.service
```

## 8. Agrega los snippets de niri

Copia el contenido de `niri/config.kdl.snippets` dentro de tu
`~/.config/niri/config.kdl` (al nivel raíz del archivo, junto a `input {}`,
`layout {}`, etc). Léelo primero — cada bloque explica por qué existe.

Luego recarga:

```bash
niri msg action load-config-file
```

## 9. Prueba

Cambia de wallpaper (el atajo por defecto de iNiR es `Mod+W`). El bar, los
paneles, y el `focus-ring` de niri deberían cambiar de color juntos.

## Problemas conocidos / gotchas

- **`inir doctor` no es seguro correrlo en NixOS.** Su modo auto-fix asume
  Arch: puede reinstalar un launcher en `~/.local/bin/inir` y escribir un
  `inir.service` a mano en `~/.config/systemd/user/`, que systemd prioriza
  sobre el que genera Nix (`/etc/systemd/user/`), dejando tu configuración
  declarativa completamente ignorada sin ningún error visible. Si lo corres
  por accidente, revisa y borra esas dos rutas.
- **Si `inir.service` no aplica cambios de entorno tras un rebuild**, casi
  siempre falta `systemctl --user daemon-reload && systemctl --user restart
  inir.service` — `nixos-rebuild switch` actualiza la definición del
  servicio en disco, pero no reinicia el proceso que ya estaba corriendo.
- **Si el venv de `~/.local/share/inir/venv` da "No existe el fichero o el
  directorio"** después de un rebuild, es porque el `python3` al que
  apuntaba su symlink dejó de existir en el store (versión distinta). Hay
  que recrear el venv (paso 7) cada vez que esto pase — no hay forma de
  evitarlo del todo con un venv suelto en `$HOME`; considera migrar a
  `python3.withPackages` (ya declarado en `inir-deps.nix`) como fuente de
  verdad en el futuro, en vez de depender del venv manual.
