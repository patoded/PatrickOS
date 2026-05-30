#!/usr/bin/env bash
# openclaw-tools.sh — lectura del registry de herramientas de OpenClaw.
# NO ejecuta herramientas, NO toca red, NO carga runtime. Es un viewer
# read-only contra configs/openclaw-tools.yaml. Ver
# docs/OPENCLAW_TOOL_CONTRACTS.md para el contrato completo.
#
# Uso:
#   openclaw-tools.sh path     imprime ruta del openclaw-tools.yaml
#   openclaw-tools.sh show     imprime el contenido del YAML
#   openclaw-tools.sh list     lista herramientas habilitadas (en Beta-0: ninguna)
#
# Búsqueda del archivo (primer hit gana):
#   1. $PATRICK_OS_TOOLS (override explícito)
#   2. <repo>/configs/openclaw-tools.yaml (modo repo)
#   3. /usr/local/share/patrick-os/configs/openclaw-tools.yaml (instalado)

set -uo pipefail

script_dir="$(cd "$(dirname "$0")" && pwd)"

TOOLS=""
if [ -n "${PATRICK_OS_TOOLS:-}" ] && [ -f "$PATRICK_OS_TOOLS" ]; then
    TOOLS="$PATRICK_OS_TOOLS"
elif [ -f "$(dirname "$script_dir")/configs/openclaw-tools.yaml" ]; then
    TOOLS="$(dirname "$script_dir")/configs/openclaw-tools.yaml"
elif [ -f "/usr/local/share/patrick-os/configs/openclaw-tools.yaml" ]; then
    TOOLS="/usr/local/share/patrick-os/configs/openclaw-tools.yaml"
fi

cmd="${1:-list}"

case "$cmd" in
    path)
        if [ -z "$TOOLS" ]; then
            echo "Error: openclaw-tools.yaml no encontrada (probé \$PATRICK_OS_TOOLS, repo/configs/, /usr/local/share/...)." >&2
            exit 1
        fi
        echo "$TOOLS"
        ;;
    show)
        if [ -z "$TOOLS" ]; then
            echo "Error: openclaw-tools.yaml no encontrada." >&2
            exit 1
        fi
        echo "# tools: $TOOLS"
        cat "$TOOLS"
        ;;
    list)
        if [ -z "$TOOLS" ]; then
            # Si el archivo no existe, asumimos "nada habilitado" — es
            # equivalente desde el punto de vista del usuario y no
            # rompe hosts viejos sin el config nuevo.
            echo "No hay herramientas habilitadas."
            exit 0
        fi
        # Atajo: si tools: [] literal, no hay candidatas — sentinel
        # directo, sin tocar el resto.
        if grep -qE '^tools:[[:space:]]*\[\][[:space:]]*$' "$TOOLS"; then
            echo "No hay herramientas habilitadas."
            exit 0
        fi
        # Listar candidatas por bloque: '  - name: X' + el primer
        # 'enabled: <bool>' que aparezca dentro del mismo bloque.
        # Si la candidata no declara enabled, asumimos disabled
        # (consistente con default_state).
        awk '
            BEGIN { block = ""; state = "?" }
            function flush() {
                if (block != "") {
                    printf "%s %s\n", block, state
                    block = ""; state = "?"
                }
            }
            /^  - name:/ {
                flush()
                block = $0
                sub(/^  - name:[[:space:]]+/, "", block)
                state = "disabled"
            }
            /^[[:space:]]+enabled:[[:space:]]+true[[:space:]]*$/  { state = "enabled" }
            /^[[:space:]]+enabled:[[:space:]]+false[[:space:]]*$/ { state = "disabled" }
            END { flush() }
        ' "$TOOLS"
        # Sentinel global: si NO hay ninguna tool con 'enabled: true',
        # mantenemos la línea histórica que el doctor y los tests
        # negativos buscan.
        if ! grep -qE '^[[:space:]]+enabled:[[:space:]]+true[[:space:]]*$' "$TOOLS"; then
            echo "No hay herramientas habilitadas."
        fi
        ;;
    *)
        echo "Uso: $0 {path|show|list}" >&2
        exit 1
        ;;
esac
