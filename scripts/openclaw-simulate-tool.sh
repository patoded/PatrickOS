#!/usr/bin/env bash
# openclaw-simulate-tool.sh — simulación de invocación de tool
# candidata. NO ejecuta herramienta real. Valida que la tool exista
# en configs/openclaw-tools.yaml y que enabled: false; si pasa,
# imprime el plan de simulación y audita 'tool_simulated'. Si la
# tool no existe o está enabled: true, FAIL + audit
# correspondiente. Args extra se imprimen como parte del plan; no
# se pasan a ningún binario.
#
# Uso:
#   openclaw-simulate-tool.sh <tool_name> [args...]
#
# Audit events (nuevos en este PR):
#   tool_simulated         simulación correcta (registry OK, tool disabled)
#   tool_unknown           tool no figura en registry o nombre inválido
#   tool_enabled_forbidden tool con enabled: true (prohibido en Beta-0/v0.4)

set -uo pipefail

script_dir="$(cd "$(dirname "$0")" && pwd)"

OS_HOME="${PATRICK_OS_HOME:-$HOME/.patrick-os}"
LOG_DIR="$OS_HOME/openclaw"
AUDIT_FILE="$LOG_DIR/audit.log"

# Resolución del registry (mismo patrón que openclaw-tools.sh /
# openclaw-contracts.sh).
TOOLS=""
if [ -n "${PATRICK_OS_TOOLS:-}" ] && [ -f "$PATRICK_OS_TOOLS" ]; then
    TOOLS="$PATRICK_OS_TOOLS"
elif [ -f "$(dirname "$script_dir")/configs/openclaw-tools.yaml" ]; then
    TOOLS="$(dirname "$script_dir")/configs/openclaw-tools.yaml"
elif [ -f "/usr/local/share/patrick-os/configs/openclaw-tools.yaml" ]; then
    TOOLS="/usr/local/share/patrick-os/configs/openclaw-tools.yaml"
fi

# Helper de audit, inline. Mismo formato que el de openclaw-stub.sh
# (ver docs/OPENCLAW_BETA0_SPEC.md sección Eventos auditados).
audit_log() {
    local event="$1"
    local mode="${2:--}"
    local result="$3"
    local detail="${4:-}"
    mkdir -p "$LOG_DIR" 2>/dev/null || return 0
    detail="$(printf '%s' "$detail" | tr -d '\n\r')"
    printf '%s | event=%s | mode=%s | result=%s | detail=%s\n' \
        "$(date '+%Y-%m-%d %H:%M:%S')" \
        "$event" "$mode" "$result" "$detail" \
        >> "$AUDIT_FILE"
}

usage() {
    cat <<'EOF'
Uso:
  openclaw-simulate-tool.sh <tool_name> [args...]

NO ejecuta herramienta real. Valida que la tool exista en el
registry y que esté disabled, y emite un plan de simulación + audit.
EOF
}

tool_name="${1:-}"
if [ -z "$tool_name" ]; then
    usage >&2
    exit 1
fi
shift || true

# Validación de nombre: solo [a-z][a-z0-9_]* (el mismo conjunto que
# contracts.sh exige). Esto también previene inyección en el grep
# que viene después — el nombre se interpola tal cual en el regex.
if ! echo "$tool_name" | grep -qE '^[a-z][a-z0-9_]*$'; then
    audit_log "tool_unknown" "-" "fail" "tool=$tool_name (nombre inválido)"
    echo "Error: tool name '$tool_name' inválido (solo [a-z][a-z0-9_]*)." >&2
    exit 1
fi

if [ -z "$TOOLS" ]; then
    audit_log "tool_unknown" "-" "fail" "registry no encontrado tool=$tool_name"
    echo "Error: configs/openclaw-tools.yaml no encontrada." >&2
    exit 1
fi

# Buscar bloque de la tool: detección por línea exacta '  - name: <X>'.
if ! grep -qE "^  - name:[[:space:]]+${tool_name}[[:space:]]*$" "$TOOLS"; then
    audit_log "tool_unknown" "-" "fail" "tool=$tool_name"
    echo "Error: tool '$tool_name' no está en el registry ($TOOLS)." >&2
    exit 1
fi

# Detectar enabled dentro del bloque. awk: arrancamos al matchear
# '  - name: <tool>' y leemos hasta el próximo '  - name:' o EOF.
# Primer 'enabled: <bool>' encontrado dentro del bloque manda.
tool_enabled=$(awk -v needle="$tool_name" '
    BEGIN { in_block = 0 }
    /^  - name:[[:space:]]+/ {
        if (in_block) { exit }
        name = $0
        sub(/^  - name:[[:space:]]+/, "", name)
        if (name == needle) { in_block = 1 }
        next
    }
    in_block && /^[[:space:]]+enabled:[[:space:]]+true[[:space:]]*$/  { print "true";  exit }
    in_block && /^[[:space:]]+enabled:[[:space:]]+false[[:space:]]*$/ { print "false"; exit }
' "$TOOLS")

# Ausencia del campo enabled = YAML mal formado. La política segura
# es NO simular (sería ocultar el bug) y reportar como unknown.
if [ -z "$tool_enabled" ]; then
    audit_log "tool_unknown" "-" "fail" "tool=$tool_name sin campo enabled"
    echo "Error: tool '$tool_name' no declara campo 'enabled' en el registry." >&2
    exit 1
fi

if [ "$tool_enabled" = "true" ]; then
    audit_log "tool_enabled_forbidden" "-" "blocked" "tool=$tool_name args=$*"
    echo "Error: tool '$tool_name' tiene enabled: true (prohibido en Beta-0/v0.4)." >&2
    echo "       Ningún tool puede estar enabled hasta que el runtime + controles de Beta-1 estén en código." >&2
    exit 1
fi

# Simulación correcta: tool existe, está disabled, registry sano.
audit_log "tool_simulated" "-" "ok" "tool=$tool_name args=$*"
echo "OpenClaw Tool Simulation"
echo "Tool: $tool_name"
echo "Status: simulated-only"
echo "Execution: disabled"
echo "Reason: Beta-1 preparation, no runtime real"
if [ "$#" -gt 0 ]; then
    echo "Args (sin ejecutar):"
    for a in "$@"; do
        echo "  - $a"
    done
fi
exit 0
