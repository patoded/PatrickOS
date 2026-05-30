#!/usr/bin/env bash
# openclaw-stub.sh — OpenClaw Beta-0 dry-run.
# Acepta una tarea, crea workspace por modo, escribe un plan markdown y
# un log mínimo. NO ejecuta herramientas reales, NO toca red, NO escala
# privilegios, NO carga runtime. Ver docs/OPENCLAW_BETA0_SPEC.md.
#
# Uso:
#   openclaw-stub.sh                       (alias de status)
#   openclaw-stub.sh status
#   openclaw-stub.sh run "tarea"
#   openclaw-stub.sh run --mode <modo> "tarea"
#
# Modo default: desarrollo
# Modos permitidos: consulta, clase, video, desarrollo, ia, general
#
# Almacenamiento (todo bajo $PATRICK_OS_HOME, default $HOME/.patrick-os):
#   $PATRICK_OS_HOME/openclaw/openclaw.log         log append-only
#   $PATRICK_OS_HOME/workspaces/<modo>/last-plan.md plan más reciente

set -euo pipefail

OS_HOME="${PATRICK_OS_HOME:-$HOME/.patrick-os}"
LOG_DIR="$OS_HOME/openclaw"
LOG_FILE="$LOG_DIR/openclaw.log"
WORKSPACES_DIR="$OS_HOME/workspaces"
ALLOWED_MODES=(consulta clase video desarrollo ia general)

print_status() {
    echo "OpenClaw Runtime: stub"
    echo "Estado: no instalado / no activo"
    echo "Modo seguro: sin ejecución de herramientas"
    echo "Beta-0 dry-run disponible: openclaw-stub.sh run \"tarea\""
    echo "Próximo paso: integrar runtime aislado con whitelist"
}

usage() {
    cat <<'EOF'
Uso:
  openclaw-stub.sh status
  openclaw-stub.sh run "tarea"
  openclaw-stub.sh run --mode <modo> "tarea"

Modos permitidos: consulta, clase, video, desarrollo (default), ia, general
EOF
}

mode_allowed() {
    local m="$1"
    for am in "${ALLOWED_MODES[@]}"; do
        [ "$am" = "$m" ] && return 0
    done
    return 1
}

cmd="${1:-status}"
shift || true

case "$cmd" in
    status|"")
        print_status
        exit 0
        ;;
    policy)
        # Delegar en openclaw-policy.sh. Cualquier arg extra se pasa
        # ('show' por default si no hay nada). Mantenemos el script
        # de policy al lado nuestro (mismo dir).
        pol_script="$(dirname "$0")/openclaw-policy.sh"
        if [ ! -x "$pol_script" ]; then
            echo "Error: openclaw-policy.sh no presente en $(dirname "$0")." >&2
            exit 1
        fi
        exec "$pol_script" "$@"
        ;;
    run)
        mode="desarrollo"
        # --mode opcional debe ir antes del texto libre.
        if [ "${1:-}" = "--mode" ]; then
            shift || true
            if [ -z "${1:-}" ]; then
                echo "Error: --mode requiere un valor." >&2
                usage >&2
                exit 1
            fi
            mode="$1"
            shift || true
        fi
        if ! mode_allowed "$mode"; then
            echo "Error: modo '$mode' no permitido." >&2
            echo "Modos permitidos: ${ALLOWED_MODES[*]}" >&2
            exit 1
        fi
        # El resto de los argumentos es la tarea. Watson nos pasa los
        # tokens ya separados, así que rejuntamos con espacios simples.
        tarea="${*:-}"
        tarea="${tarea#"${tarea%%[![:space:]]*}"}"
        tarea="${tarea%"${tarea##*[![:space:]]}"}"
        if [ -z "$tarea" ]; then
            echo "Error: tarea vacía." >&2
            usage >&2
            exit 1
        fi

        # Policy gate: si la policy local permite algo inseguro (red,
        # sudo, plugins, marketplace, whitelist no vacía, kill switch
        # off) abortamos antes de tocar nada. Mantenemos el dry-run
        # honesto: ningún plan se escribe si las invariantes no se
        # cumplen.
        pol_script="$(dirname "$0")/openclaw-policy.sh"
        if [ -x "$pol_script" ]; then
            if ! "$pol_script" check >/dev/null 2>&1; then
                echo "Error: policy check falló. Corré '$pol_script check' para ver el detalle." >&2
                exit 1
            fi
        else
            echo "Error: openclaw-policy.sh no presente en $(dirname "$0"); no puedo ejecutar dry-run sin policy gate." >&2
            exit 1
        fi

        ws_dir="$WORKSPACES_DIR/$mode"
        plan_file="$ws_dir/last-plan.md"
        mkdir -p "$LOG_DIR"
        # Delegar la creación del workspace (dir + README) en
        # workspace.sh para mantener una sola convención de
        # path/inicialización. Fallback a mkdir si por algún motivo
        # workspace.sh no está al lado.
        ws_script="$(dirname "$0")/workspace.sh"
        if [ -x "$ws_script" ]; then
            "$ws_script" init "$mode" >/dev/null
        else
            mkdir -p "$ws_dir"
        fi

        fecha="$(date '+%Y-%m-%d %H:%M:%S')"
        # Sobrescribimos last-plan.md a propósito: es "el último plan".
        # El historial completo va al log append-only.
        cat > "$plan_file" <<EOF_PLAN
# OpenClaw Dry Run Plan
Fecha: $fecha
Modo: $mode
Tarea: $tarea
Herramientas permitidas: ninguna
Red: deshabilitada
Sudo: deshabilitado
Policy: OK
Tool whitelist: empty
Kill switch: enabled
Estado: dry-run, nada ejecutado
EOF_PLAN

        printf '%s | mode=%s | dry-run | task=%s\n' \
            "$fecha" "$mode" "$tarea" >> "$LOG_FILE"

        echo "OpenClaw Beta-0 dry-run"
        echo "Modo: $mode"
        echo "Plan: $plan_file"
        echo "Estado: dry-run, nada ejecutado"
        exit 0
        ;;
    *)
        echo "Subcomando desconocido: $cmd" >&2
        usage >&2
        exit 1
        ;;
esac
