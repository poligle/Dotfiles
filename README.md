# Dotfiles - Arch Linux + Hyprland

Configuración personal para un entorno basado en Arch Linux usando Hyprland.

---

## 📦 Contenido

* Hyprland (wm)
* Waybar (barra)
* Wofi (launcher)
* Dunst (notificaciones)
* Kitty (terminal)
* Neovim
* GTK / Qt settings

---

## 🚀 Instalación

Clonar el repositorio:

```bash
git clone https://github.com/TU_USUARIO/dotfiles.git
cd dotfiles
```

Ejecutar el script de instalación:

```bash
bash install.sh
```

---

## ⚙️ Qué hace el script

* Instala paquetes oficiales (`pacman`)
* Instala paquetes AUR (si tienes `yay` o `paru`)
* Copia configuraciones a `~/.config`
* Hace backup de configuraciones existentes

---

## 📋 Requisitos

* Arch Linux
* `git`
* `sudo`

Opcional (para AUR):

* `yay` o `paru`

---

## 📁 Estructura del repositorio

```text
dotfiles/
├── .config/          # Configuraciones de usuario
├── packages/         # Listas de paquetes
│   ├── pkglist
│   └── pkglist_aur
├── install.sh
├── README.md
└── .gitignore
```

---

## ⚠️ Notas importantes

* El script no elimina tu configuración actual, hace backup automático.
* Algunas configuraciones pueden depender de elementos externos como:

  * fuentes (ej: Nerd Fonts)
  * wallpapers
  * scripts en `~/.local/bin`
* Asegúrate de tener estos elementos si algo no se ve correctamente.

---

## 🔄 Restauración manual (opcional)

Si no quieres usar el script:

```bash
cp -r .config/* ~/.config/
```

Instalar paquetes:

```bash
sudo pacman -S --needed - < packages/pkglist
```

AUR:

```bash
yay -S --needed - < packages/pkglist_aur
```

---

## 🧪 Recomendación

Para probar en limpio:

```bash
mv ~/.config ~/.config.backup
mkdir ~/.config

bash install.sh
```

---

## 📌 TO DO / mejoras futuras

* [ ] Añadir wallpapers al repo o documentarlos
* [ ] Script para instalar AUR automáticamente
* [ ] Gestión de fuentes

---

## 📄 Licencia

GNU

