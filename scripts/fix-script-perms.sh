#!/usr/bin/env bash
# fix-script-perms.sh — restaura +x sobre scripts/*.sh.
# Recuperación rápida del bug del share SMB de WSL (ver
# check-executable-scripts.sh). Idempotente: si todo ya está +x, no
# hace nada y sale 0.

set -e
script_dir="$(cd "$(dirname "$0")" && pwd)"

shopt -s nullglob
scripts=("$script_dir"/*.sh)
shopt -u nullglob

if [ "${#scripts[@]}" -eq 0 ]; then
    echo "No hay .sh en $script_dir; nada que hacer."
    exit 0
fi

corrected=()
already_ok=()
for f in "${scripts[@]}"; do
    if [ -x "$f" ]; then
        already_ok+=("$f")
    else
        chmod +x "$f"
        corrected+=("$f")
    fi
done

if [ "${#corrected[@]}" -gt 0 ]; then
    echo "chmod +x aplicado a ${#corrected[@]} script(s):"
    printf '  %s\n' "${corrected[@]}"
else
    echo "Todos los scripts (${#already_ok[@]}) ya eran ejecutables."
fi
exit 0
