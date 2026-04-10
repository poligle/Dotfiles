#!/usr/bin/env bash
set -Eeuo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="$REPO_DIR/.config"
SCRIPTS_DIR="$REPO_DIR/scripts"
PACKAGES_DIR="$REPO_DIR/packages"
PKGLIST="$PACKAGES_DIR/pkglist"
PKGLIST_AUR="$PACKAGES_DIR/pkglist_aur"

INSTALL_PACKAGES=true
INSTALL_AUR=true
INSTALL_CONFIG=true
INSTALL_SCRIPTS=true
FORCE_OVERWRITE=false
SKIP_YAY_BOOTSTRAP=false

timestamp() {
  date +"%Y-%m-%d %H:%M:%S"
}

log() {
  printf "[%s] %s\n" "$(timestamp)" "$*"
}

warn() {
  printf "[%s] [WARN] %s\n" "$(timestamp)" "$*" >&2
}

err() {
  printf "[%s] [ERROR] %s\n" "$(timestamp)" "$*" >&2
}

die() {
  err "$*"
  exit 1
}

usage() {
  cat <<'EOF'
Uso: bash install.sh [opciones]

Opciones:
  --only-packages     Solo instala paquetes oficiales
  --only-aur          Solo instala paquetes AUR
  --only-config       Solo copia ~/.config
  --only-scripts      Solo copia scripts a ~/.local/bin

  --no-packages       No instala paquetes oficiales
  --no-aur            No instala paquetes AUR
  --no-config         No copia ~/.config
  --no-scripts        No copia scripts

  --force             Sobrescribe destino sin backup
  --skip-yay-bootstrap No intenta instalar yay automáticamente
  -h, --help          Muestra esta ayuda

Ejemplos:
  bash install.sh
  bash install.sh --no-aur
  bash install.sh --only-config
  bash install.sh --only-packages --only-aur
EOF
}

parse_args() {
  if [[ $# -eq 0 ]]; then
    return
  fi

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --only-packages)
        INSTALL_PACKAGES=true
        INSTALL_AUR=false
        INSTALL_CONFIG=false
        INSTALL_SCRIPTS=false
        ;;
      --only-aur)
        INSTALL_PACKAGES=false
        INSTALL_AUR=true
        INSTALL_CONFIG=false
        INSTALL_SCRIPTS=false
        ;;
      --only-config)
        INSTALL_PACKAGES=false
        INSTALL_AUR=false
        INSTALL_CONFIG=true
        INSTALL_SCRIPTS=false
        ;;
      --only-scripts)
        INSTALL_PACKAGES=false
        INSTALL_AUR=false
        INSTALL_CONFIG=false
        INSTALL_SCRIPTS=true
        ;;
      --no-packages)
        INSTALL_PACKAGES=false
        ;;
      --no-aur)
        INSTALL_AUR=false
        ;;
      --no-config)
        INSTALL_CONFIG=false
        ;;
      --no-scripts)
        INSTALL_SCRIPTS=false
        ;;
      --force)
        FORCE_OVERWRITE=true
        ;;
      --skip-yay-bootstrap)
        SKIP_YAY_BOOTSTRAP=true
        ;;
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
  if [[ ! -f /etc/arch-release ]]; then
    die "Este script está pensado para Arch Linux o derivadas con pacman."
  fi
}

backup_path() {
  local target="$1"
  local backup="${target}.bak.$(date +%Y%m%d%H%M%S)"
  mv "$target" "$backup"
  log "Backup creado: $backup"
}

copy_item() {
  local src="$1"
  local dest="$2"

  if [[ ! -e "$src" ]]; then
    warn "No existe la fuente: $src"
    return
  fi

  mkdir -p "$(dirname "$dest")"

  if [[ -e "$dest" || -L "$dest" ]]; then
    if [[ "$FORCE_OVERWRITE" == true ]]; then
      rm -rf "$dest"
      log "Sobrescrito: $dest"
    else
      backup_path "$dest"
    fi
  fi

  cp -a "$src" "$dest"
  log "Copiado: $src -> $dest"
}

install_official_packages() {
  [[ "$INSTALL_PACKAGES" == true ]] || return 0

  if [[ ! -f "$PKGLIST" ]]; then
    warn "No se encontró $PKGLIST. Salto paquetes oficiales."
    return 0
  fi

  log "Instalando paquetes oficiales desde $PKGLIST"
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

  log "Instalando dependencias para bootstrap de yay"
  sudo pacman -S --needed --noconfirm git base-devel

  local tmpdir
  tmpdir="$(mktemp -d)"
  trap 'rm -rf "$tmpdir"' RETURN

  log "Clonando yay desde AUR"
  git clone https://aur.archlinux.org/yay.git "$tmpdir/yay"

  pushd "$tmpdir/yay" >/dev/null
  log "Compilando e instalando yay"
  makepkg -si --noconfirm
  popd >/dev/null

  if ! command -v yay >/dev/null 2>&1; then
    die "No se pudo instalar yay"
  fi

  log "yay instalado correctamente"
}

install_aur_packages() {
  [[ "$INSTALL_AUR" == true ]] || return 0

  if [[ ! -f "$PKGLIST_AUR" ]]; then
    warn "No se encontró $PKGLIST_AUR. Salto paquetes AUR."
    return 0
  fi

  if command -v yay >/dev/null 2>&1; then
    log "Instalando paquetes AUR con yay desde $PKGLIST_AUR"
    yay -S --needed --noconfirm - < "$PKGLIST_AUR"
  elif command -v paru >/dev/null 2>&1; then
    log "Instalando paquetes AUR con paru desde $PKGLIST_AUR"
    paru -S --needed --noconfirm - < "$PKGLIST_AUR"
  else
    warn "No se encontró yay ni paru. Salto AUR."
  fi
}

install_config() {
  [[ "$INSTALL_CONFIG" == true ]] || return 0

  if [[ ! -d "$CONFIG_DIR" ]]; then
    warn "No se encontró $CONFIG_DIR. Salto copia de .config."
    return 0
  fi

  log "Copiando configuraciones a $HOME/.config"
  mkdir -p "$HOME/.config"

  shopt -s dotglob nullglob
  for src in "$CONFIG_DIR"/*; do
    local name
    name="$(basename "$src")"
    copy_item "$src" "$HOME/.config/$name"
  done
  shopt -u dotglob nullglob
}

install_scripts() {
  [[ "$INSTALL_SCRIPTS" == true ]] || return 0

  if [[ ! -d "$SCRIPTS_DIR" ]]; then
    warn "No se encontró $SCRIPTS_DIR. Salto copia de scripts."
    return 0
  fi

  log "Copiando scripts a $HOME/.local/bin"
  mkdir -p "$HOME/.local/bin"

  shopt -s dotglob nullglob
  for src in "$SCRIPTS_DIR"/*; do
    local name
    name="$(basename "$src")"
    copy_item "$src" "$HOME/.local/bin/$name"
    chmod +x "$HOME/.local/bin/$name" || true
  done
  shopt -u dotglob nullglob
}

ensure_local_bin_in_path() {
  local shell_rc=""

  if [[ -n "${ZSH_VERSION:-}" ]]; then
    shell_rc="$HOME/.zshrc"
  elif [[ -n "${BASH_VERSION:-}" ]]; then
    shell_rc="$HOME/.bashrc"
  else
    warn "No pude detectar shell actual para comprobar PATH"
    return 0
  fi

  if [[ -f "$shell_rc" ]] && grep -qE '(^|:)\$HOME/\.local/bin(:|$)|(^|:)~\/\.local/bin(:|$)' "$shell_rc"; then
    log "~/.local/bin ya parece estar en PATH según $shell_rc"
    return 0
  fi

  warn "Asegúrate de tener \$HOME/.local/bin en tu PATH"
}

show_summary() {
  cat <<EOF

Resumen:
  Repo:              $REPO_DIR
  Paquetes oficiales: $( [[ "$INSTALL_PACKAGES" == true ]] && echo "sí" || echo "no" )
  Paquetes AUR:       $( [[ "$INSTALL_AUR" == true ]] && echo "sí" || echo "no" )
  Configs:            $( [[ "$INSTALL_CONFIG" == true ]] && echo "sí" || echo "no" )
  Scripts:            $( [[ "$INSTALL_SCRIPTS" == true ]] && echo "sí" || echo "no" )
  Force overwrite:    $( [[ "$FORCE_OVERWRITE" == true ]] && echo "sí" || echo "no" )

Notas:
  - Revisa fuentes, wallpapers y otras dependencias externas si algo no se ve igual.
  - Si usas scripts personalizados, verifica que sus dependencias estén en pkglist o pkglist_aur.
EOF
}

main() {
  parse_args "$@"
  check_arch
  require_cmd cp
  require_cmd mv
  require_cmd sudo

  log "Iniciando instalación desde $REPO_DIR"

  install_official_packages
  bootstrap_yay
  install_aur_packages
  install_config
  install_scripts
  ensure_local_bin_in_path

  log "Instalación completada"
  show_summary
}

main "$@"
