#!/usr/bin/env bash

DIR="$HOME/Wallpapers"
STATE_FILE="${XDG_CACHE_HOME:-$HOME/.cache}/wallpaper_index"
CURRENT_LINK="${XDG_CACHE_HOME:-$HOME/.cache}/current_wallpaper"

mkdir -p "$(dirname "$STATE_FILE")"

mapfile -t WALLS < <(
    find -L "$DIR" -type f \( \
        -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" \
        -o -iname "*.webp" -o -iname "*.gif" \
    \) | sort
)

TOTAL=${#WALLS[@]}
[[ $TOTAL -eq 0 ]] && exit 1

INDEX=0
[[ -f "$STATE_FILE" ]] && read -r INDEX < "$STATE_FILE"

INDEX=$(( (INDEX + 1) % TOTAL ))
printf "%s\n" "$INDEX" > "$STATE_FILE"

NEXT_WALL="${WALLS[$INDEX]}"

if command -v awww >/dev/null 2>&1; then
    awww img "$NEXT_WALL" --transition-type random
elif command -v swww >/dev/null 2>&1; then
    swww img "$NEXT_WALL" --transition-type random
else
    echo "No encuentro ni 'awww' ni 'swww' en PATH" >&2
    exit 1
fi

ln -sf "$NEXT_WALL" "$CURRENT_LINK"
