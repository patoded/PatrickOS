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
AUDIT_FILE="$LOG_DIR/audit.log"
KILL_SWITCH="$LOG_DIR/KILL_SWITCH"
WORKSPACES_DIR="$OS_HOME/workspaces"
ALLOWED_MODES=(consulta clase video desarrollo ia general)

audit_log() {
    # Una línea por evento, formato estable parseable. Detail puede ser
    # texto libre (tarea recibida, razón del kill, etc.) pero sin
    # newlines — el formato es estrictamente una línea por entrada.
    # Mode vacío se escribe como '-' para que el campo no quede colgado.
    local event="$1"
    local mode="${2:--}"
    local result="$3"
    local detail="${4:-}"
    mkdir -p "$LOG_DIR" 2>/dev/null || return 0
    # tr -d '\n\r' por defensa: si alguien pasa una tarea con \n, no
    # corrompemos el formato. Los | en detail los dejamos pasar — son
    # menos comunes y el parser puede manejar | como separador "hasta
    # primer occurrence" + resto como detail.
    detail="$(printf '%s' "$detail" | tr -d '\n\r')"
    printf '%s | event=%s | mode=%s | result=%s | detail=%s\n' \
        "$(date '+%Y-%m-%d %H:%M:%S')" \
        "$event" "$mode" "$result" "$detail" \
        >> "$AUDIT_FILE"
}

print_status() {
    echo "OpenClaw Runtime: stub"
    echo "Estado: no instalado / no activo"
    echo "Modo seguro: sin ejecución de herramientas"
    echo "Beta-0 dry-run disponible: openclaw-stub.sh run \"tarea\""
    echo "Próximo paso: integrar runtime aislado con whitelist"
    if [ -f "$KILL_SWITCH" ]; then
        echo "KILL_SWITCH: activo ($KILL_SWITCH)"
    else
        echo "KILL_SWITCH: inactivo"
    fi
}

usage() {
    cat <<'EOF'
Uso:
  openclaw-stub.sh status
  openclaw-stub.sh run "tarea"
  openclaw-stub.sh run --mode <modo> "tarea"
  openclaw-stub.sh kill ["razón"]
  openclaw-stub.sh unkill
  openclaw-stub.sh policy [show|path|check]

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
        audit_log "status" "-" "info" ""
        print_status
        exit 0
        ;;
    kill)
        # Crea el archivo KILL_SWITCH. Si hay args, los junta y guarda
        # como 'reason'. Idempotente: pisar es válido (refresh del
        # timestamp/razón).
        mkdir -p "$LOG_DIR"
        razon="${*:-}"
        razon="${razon#"${razon%%[![:space:]]*}"}"
        razon="${razon%"${razon##*[![:space:]]}"}"
        ts="$(date '+%Y-%m-%d %H:%M:%S')"
        if [ -z "$razon" ]; then
            printf 'killed_at: %s\n' "$ts" > "$KILL_SWITCH"
        else
            printf 'killed_at: %s\nreason: %s\n' "$ts" "$razon" > "$KILL_SWITCH"
        fi
        audit_log "kill" "-" "info" "$razon"
        echo "KILL_SWITCH activado: $KILL_SWITCH"
        [ -n "$razon" ] && echo "Razón: $razon"
        exit 0
        ;;
    unkill)
        if [ -f "$KILL_SWITCH" ]; then
            rm -f "$KILL_SWITCH"
            audit_log "unkill" "-" "info" ""
            echo "KILL_SWITCH desactivado: $KILL_SWITCH"
        else
            audit_log "unkill" "-" "info" "noop (ya inactivo)"
            echo "KILL_SWITCH ya estaba inactivo ($KILL_SWITCH)."
        fi
        exit 0
        ;;
    policy)
        # Delegar en openclaw-policy.sh. Cualquier arg extra se pasa
        # ('show' por default si no hay nada). Mantenemos el script
        # de policy al lado nuestro (mismo dir). Auditamos ANTES del
        # exec — después del exec ya somos otro proceso.
        pol_script="$(dirname "$0")/openclaw-policy.sh"
        if [ ! -x "$pol_script" ]; then
            audit_log "policy" "-" "fail" "openclaw-policy.sh no presente"
            echo "Error: openclaw-policy.sh no presente en $(dirname "$0")." >&2
            exit 1
        fi
        audit_log "policy" "-" "info" "${1:-show}"
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
            audit_log "run_invalid_mode" "$mode" "fail" "modo no permitido"
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
            audit_log "run_empty_task" "$mode" "fail" "tarea vacía"
            echo "Error: tarea vacía." >&2
            usage >&2
            exit 1
        fi

        # Kill switch local: si el archivo KILL_SWITCH existe, ningún
        # run sale — ni siquiera dry-run. Es la pausa táctica del usuario
        # y gana sobre la policy y sobre todo lo demás. Se desactiva con
        # 'openclaw-stub.sh unkill'.
        if [ -f "$KILL_SWITCH" ]; then
            audit_log "run_blocked_kill_switch" "$mode" "blocked" "$tarea"
            echo "OpenClaw bloqueado por KILL_SWITCH" >&2
            echo "Archivo: $KILL_SWITCH" >&2
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
                audit_log "run_blocked_policy" "$mode" "blocked" "$tarea"
                echo "Error: policy check falló. Corré '$pol_script check' para ver el detalle." >&2
                exit 1
            fi
        else
            audit_log "run_blocked_policy" "$mode" "blocked" "openclaw-policy.sh ausente"
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
        # El historial completo va al log append-only + audit log.
        # Si KILL_SWITCH estuviera activo ya habríamos abortado más
        # arriba, así que acá lo reportamos como 'disabled' (no
        # engaged) por construcción.
        # 'Interpretación' es deliberadamente la tarea literal: sin
        # LLM en este path, cualquier "resumen" sería inventado;
        # devolver el texto del usuario es la opción honesta.
        cat > "$plan_file" <<EOF_PLAN
# OpenClaw Dry Run Plan

## Metadata
Fecha: $fecha
Modo: $mode
Workspace: $ws_dir
Policy: OK
Tool whitelist: empty
Kill switch: disabled

## Tarea solicitada
$tarea

## Interpretación
$tarea

## Plan propuesto
1. Revisar contexto local permitido.
2. Definir pasos seguros.
3. Confirmar antes de cualquier ejecución real futura.

## Herramientas
- Permitidas: ninguna
- Red: deshabilitada
- Sudo: deshabilitado
- Plugins: deshabilitados
- Marketplace: deshabilitado

## Estado
Dry-run. Nada ejecutado.
EOF_PLAN

        # Historial: además de last-plan.md, guardamos una copia
        # inmutable en <workspace>/plans/<timestamp>-plan.md. Mismo
        # contenido — la sobrescritura de last-plan.md no pierde
        # nada. Colisiones en el mismo segundo se sobrescriben (sin
        # contador): Beta-0 prioriza auditabilidad humana sobre
        # paralelismo. Si dos runs caen al mismo segundo, gana el
        # último; el audit log igual los registra a ambos.
        plans_dir="$ws_dir/plans"
        ts_filename="$(date '+%Y%m%d-%H%M%S')"
        mkdir -p "$plans_dir"
        plan_basename="${ts_filename}-plan.md"
        cp "$plan_file" "$plans_dir/$plan_basename"

        # Índice TSV append-only: timestamp \t mode \t filename \t task.
        # Sanitizamos la tarea de tabs/newlines/CR para no romper el
        # formato — el resto pasa tal cual. Un parser razonable puede
        # cortar por tab y, si hay tabs accidentales en el campo final,
        # rejuntarlos.
        tarea_clean="$(printf '%s' "$tarea" | tr -d '\t\n\r')"
        printf '%s\t%s\t%s\t%s\n' \
            "$ts_filename" "$mode" "$plan_basename" "$tarea_clean" \
            >> "$plans_dir/index.tsv"

        printf '%s | mode=%s | dry-run | task=%s\n' \
            "$fecha" "$mode" "$tarea" >> "$LOG_FILE"
        audit_log "run_allowed" "$mode" "ok" "$tarea"

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
