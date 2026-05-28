#!/usr/bin/env bash
# check-executable-scripts.sh — verifica que todos los scripts/*.sh sean
# ejecutables. Existe porque editar un .sh a través del share SMB de WSL
# desde Windows tiende a tirarle el +x sin avisar, y los síntomas
# downstream (PermissionError dentro de Watson via ejecutar_seguro) son
# silenciosos. Este check lo destapa en make check, no en producción.
#
# Sale con código:
#   0  todos +x
#   1  al menos uno sin +x (lista cuáles y cómo arreglarlo)
#   2  no se encontró scripts/

# No 'set -e': queremos recorrer todos los scripts antes de salir.
script_dir="$(cd "$(dirname "$0")" && pwd)"

if [ ! -d "$script_dir" ]; then
    echo "ERROR: $script_dir no existe."
    exit 2
fi

shopt -s nullglob
scripts=("$script_dir"/*.sh)
shopt -u nullglob

if [ "${#scripts[@]}" -eq 0 ]; then
    echo "ERROR: no se encontró ningún .sh en $script_dir."
    exit 2
fi

bad=()
for f in "${scripts[@]}"; do
    if [ -x "$f" ]; then
        echo "[OK]   +x: $f"
    else
        echo "[FAIL] sin +x: $f"
        bad+=("$f")
    fi
done

if [ "${#bad[@]}" -gt 0 ]; then
    echo
    echo "Scripts sin permiso ejecutable: ${#bad[@]}"
    echo "Para arreglarlos: make fix-perms"
    echo "                  (o:  chmod +x ${bad[*]})"
    exit 1
fi

echo
echo "Todos los scripts (${#scripts[@]}) son ejecutables."
exit 0
