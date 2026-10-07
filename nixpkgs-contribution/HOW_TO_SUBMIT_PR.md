# 🚀 Cómo enviar iNiR a Nixpkgs (`search.nixos.org`)

Este documento explica cómo someter el paquete `inir` directamente al repositorio oficial de **NixOS/nixpkgs**, para que aparezca oficialmente en **https://search.nixos.org/packages** al igual que `noctalia-shell` o `hyprland`.

---

### 1. Clonar el Fork de Nixpkgs

Desde tu terminal (utilizando GitHub CLI `gh`):

```bash
# 1. Crear tu fork personal de Nixpkgs en GitHub y clonarlo
gh repo fork NixOS/nixpkgs --clone
cd nixpkgs

# 2. Crear una rama limpia para el paquete
git checkout -b inir-init
```

---

### 2. Copiar la derivación al árbol oficial de paquetes

Nixpkgs organiza los paquetes nuevos bajo la arquitectura `pkgs/by-name`:

```bash
# Crear el directorio estándar en nixpkgs
mkdir -p pkgs/by-name/in/inir

# Copiar el archivo package.nix preparado desde inir-nixos
cp /home/ltar/inir-nixos/nixpkgs-contribution/pkgs/by-name/in/inir/package.nix pkgs/by-name/in/inir/package.nix
```

---

### 3. Probar la compilación localmente

Antes de enviar el Pull Request, verifica que compile correctamente:

```bash
# Probar la evaluación y construcción
nix-build -A inir

# O con Nix Flakes:
nix build .#inir
```

---

### 4. Crear el Commit siguiendo las directrices de Nixpkgs

Nixpkgs exige un formato de commit específico: `<nombre-paquete>: init at <versión>`

```bash
git add pkgs/by-name/in/inir/package.nix
git commit -m "inir: init at 2.32.0"
```

---

### 5. Enviar el Pull Request a NixOS

```bash
# Subir la rama a tu fork en GitHub
git push -u origin inir-init

# Crear el Pull Request oficial a NixOS/nixpkgs
gh pr create \
  --repo NixOS/nixpkgs \
  --base master \
  --title "inir: init at 2.32.0" \
  --body "### Summary
This PR adds \`inir\`, a complete desktop shell for the Niri Wayland compositor built on Quickshell with Material You dynamic color theming.

- **Package name**: inir
- **Version**: 2.32.0
- **Homepage**: https://github.com/LATAR-web/inir
- **License**: GPL-3.0-only
- **Main program**: inir

Tested on x86_64-linux."
```

Una vez que los mantenedores de NixOS revisen y fusionen el PR, el paquete se indexará automáticamente y aparecerá en **[search.nixos.org/packages](https://search.nixos.org/packages)**.
