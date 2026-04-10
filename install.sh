#!/usr/bin/env bash
set -Eeuo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="$REPO_DIR/.config"
PACKAGES_DIR="$REPO_DIR/packages"
SCRIPTS_DIR="$REPO_DIR/scripts"
WALLPAPERS_DIR="$REPO_DIR/assets/wallpapers"

PKGLIST="$PACKAGES_DIR/pkglist.txt"
PKGLIST_AUR="$PACKAGES_DIR/pkglist_aur.txt"

CONFIG_ITEMS=(
  conky
  dunst
  gtk-3.0
  gtk-4.0
  hypr
  kitty
  nvim
  qt6ct
  waybar
  wofi
  xsettingsd
)

INSTALL_PACKAGES=true
INSTALL_AUR=true
LINK_CONFIG=true
LINK_SCRIPTS=true
LINK_WALLPAPERS=true
SKIP_YAY_BOOTSTRAP=false
FORCE=false

timestamp() {
  date +"%Y-%m-%d %H:%M:%S"
}

log() {
  printf "[%s] %s\n" "$(timestamp)" "$*"
}

warn() {
  printf "[%s] [WARN] %s\n" "$(timestamp)" "$*" >&2
}

die() {
  printf "[%s] [ERROR] %s\n" "$(timestamp)" "$*" >&2
  exit 1
}

usage() {
  cat <<'EOF'
Uso: bash install.sh [opciones]

Opciones:
  --no-packages           No instala paquetes oficiales
  --no-aur                No instala paquetes AUR
  --no-config             No crea symlinks de ~/.config
  --no-scripts            No crea symlink de ~/.local/bin
  --no-wallpapers         No crea symlink de ~/Wallpapers
  --skip-yay-bootstrap    No intenta instalar yay automáticamente
  --force                 Borra destino existente en vez de hacer backup
  -h, --help              Muestra esta ayuda

Ejemplos:
  bash install.sh
  bash install.sh --no-aur
  bash install.sh --no-packages --no-aur
EOF
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --no-packages) INSTALL_PACKAGES=false ;;
      --no-aur) INSTALL_AUR=false ;;
      --no-config) LINK_CONFIG=false ;;
      --no-scripts) LINK_SCRIPTS=false ;;
      --no-wallpapers) LINK_WALLPAPERS=false ;;
      --skip-yay-bootstrap) SKIP_YAY_BOOTSTRAP=true ;;
      --force) FORCE=true ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        die "Opción no reconocida: $1"
        ;;
    esac
    shift
  done
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "Falta el comando requerido: $1"
}

check_arch() {
  require_cmd pacman
  [[ -f /etc/arch-release ]] || die "Este script está pensado para Arch Linux."
}

backup_or_remove() {
  local target="$1"

  [[ -e "$target" || -L "$target" ]] || return 0

  if [[ "$FORCE" == true ]]; then
    rm -rf "$target"
    log "Eliminado: $target"
  else
    local backup="${target}.bak.$(date +%Y%m%d%H%M%S)"
    mv "$target" "$backup"
    log "Backup: $target -> $backup"
  fi
}

ensure_parent_dir() {
  mkdir -p "$(dirname "$1")"
}

create_symlink() {
  local source="$1"
  local target="$2"

  [[ -e "$source" || -L "$source" ]] || {
    warn "No existe la fuente: $source"
    return 0
  }

  ensure_parent_dir "$target"

  if [[ -L "$target" ]]; then
    local current
    current="$(readlink -f "$target" || true)"
    local desired
    desired="$(readlink -f "$source" || true)"
    if [[ -n "$current" && -n "$desired" && "$current" == "$desired" ]]; then
      log "Ya existe el symlink correcto: $target"
      return 0
    fi
  fi

  backup_or_remove "$target"
  ln -s "$source" "$target"
  log "Symlink: $target -> $source"
}

install_official_packages() {
  [[ "$INSTALL_PACKAGES" == true ]] || return 0

  [[ -f "$PKGLIST" ]] || {
    warn "No se encontró $PKGLIST. Salto paquetes oficiales."
    return 0
  }

  log "Instalando paquetes oficiales"
  sudo pacman -Syu --needed --noconfirm - < "$PKGLIST"
}

bootstrap_yay() {
  [[ "$INSTALL_AUR" == true ]] || return 0

  if command -v yay >/dev/null 2>&1; then
    log "yay ya está instalado"
    return 0
  fi

  if [[ "$SKIP_YAY_BOOTSTRAP" == true ]]; then
    warn "yay no está instalado y se pidió no instalarlo automáticamente"
    return 0
  fi

  log "Instalando dependencias para yay"
  sudo pacman -S --needed --noconfirm git base-devel

  local tmpdir
  tmpdir="$(mktemp -d)"
  log "Clonando yay en $tmpdir"
  git clone https://aur.archlinux.org/yay.git "$tmpdir/yay"

  pushd "$tmpdir/yay" >/dev/null
  makepkg -si --noconfirm
  popd >/dev/null

  rm -rf "$tmpdir"

  command -v yay >/dev/null 2>&1 || die "No se pudo instalar yay"
  log "yay instalado correctamente"
}

install_aur_packages() {
  [[ "$INSTALL_AUR" == true ]] || return 0

  [[ -f "$PKGLIST_AUR" ]] || {
    warn "No se encontró $PKGLIST_AUR. Salto paquetes AUR."
    return 0
  }

  if command -v yay >/dev/null 2>&1; then
    log "Instalando paquetes AUR con yay"
    yay -S --needed --noconfirm - < "$PKGLIST_AUR"
  elif command -v paru >/dev/null 2>&1; then
    log "Instalando paquetes AUR con paru"
    paru -S --needed --noconfirm - < "$PKGLIST_AUR"
  else
    warn "No se encontró yay ni paru. Salto AUR."
  fi
}

link_config_dirs() {
  [[ "$LINK_CONFIG" == true ]] || return 0
  [[ -d "$CONFIG_DIR" ]] || {
    warn "No existe $CONFIG_DIR. Salto symlinks de .config."
    return 0
  }

  mkdir -p "$HOME/.config"

  for item in "${CONFIG_ITEMS[@]}"; do
    create_symlink "$CONFIG_DIR/$item" "$HOME/.config/$item"
  done
}

link_scripts_dir() {
  [[ "$LINK_SCRIPTS" == true ]] || return 0
  [[ -d "$SCRIPTS_DIR" ]] || {
    warn "No existe $SCRIPTS_DIR. Salto symlink de scripts."
    return 0
  }

  create_symlink "$SCRIPTS_DIR" "$HOME/.local/bin"
}

link_wallpapers_dir() {
  [[ "$LINK_WALLPAPERS" == true ]] || return 0
  [[ -d "$WALLPAPERS_DIR" ]] || {
    warn "No existe $WALLPAPERS_DIR. Salto symlink de wallpapers."
    return 0
  }

  create_symlink "$WALLPAPERS_DIR" "$HOME/Wallpapers"
}

ensure_local_bin_in_path() {
  if [[ ":$PATH:" == *":$HOME/.local/bin:"* ]]; then
    log "~/.local/bin ya está en PATH"
  else
    warn "~/.local/bin no está en PATH en esta sesión"
    warn "Añádelo a tu shell si hace falta"
  fi
}

summary() {
  cat <<EOF

Instalación terminada.

Repo:             $REPO_DIR
Config symlinks:  $LINK_CONFIG
Scripts symlink:  $LINK_SCRIPTS
Wallpapers link:  $LINK_WALLPAPERS
Official pkgs:    $INSTALL_PACKAGES
AUR pkgs:         $INSTALL_AUR

Comprobaciones útiles:
  ls -l ~/.config
  ls -l ~/.local
  ls -l ~ | grep Wallpapers
  cd ~/dotfiles && git status
EOF
}

main() {
  parse_args "$@"

  check_arch
  require_cmd git
  require_cmd ln
  require_cmd mv
  require_cmd readlink
  require_cmd sudo

  log "Instalando desde $REPO_DIR"

  install_official_packages
  bootstrap_yay
  install_aur_packages
  link_config_dirs
  link_scripts_dir
  link_wallpapers_dir
  ensure_local_bin_in_path
  summary
}

main "$@"
