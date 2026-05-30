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
        # Beta-0: la lista debe estar vacía y el estado por default
        # disabled. Cualquiera de las dos condiciones dispara el
        # mensaje "ninguna habilitada", consistente con que la policy
        # también rechazaría tools con contenido.
        if grep -qE '^default_state:[[:space:]]+disabled[[:space:]]*$' "$TOOLS" \
           || grep -qE '^tools:[[:space:]]*\[\][[:space:]]*$' "$TOOLS"; then
            echo "No hay herramientas habilitadas."
            exit 0
        fi
        # Si llegamos acá, el YAML cambió a algo no-Beta-0. El viewer
        # no implementa parser real — derivamos al policy check que
        # ya tiene el guard estricto.
        echo "Registry con contenido inesperado para Beta-0. Corré 'watson policy check'." >&2
        exit 1
        ;;
    *)
        echo "Uso: $0 {path|show|list}" >&2
        exit 1
        ;;
esac
