#!/usr/bin/env bash
# openclaw-audit.sh — lectura del audit log estructurado de OpenClaw.
# NO escribe el log (el escritor es openclaw-stub.sh), NO ejecuta nada,
# NO toca red. Solo formatos de lectura.
#
# Uso:
#   openclaw-audit.sh path     imprime ruta del audit.log
#   openclaw-audit.sh list     imprime el log completo (oldest first)
#   openclaw-audit.sh tail     imprime las últimas 20 entradas (default)
#   openclaw-audit.sh summary  conteo por evento (kill / unkill / run_allowed / ...)
#
# Archivo (respeta PATRICK_OS_HOME, default $HOME/.patrick-os):
#   $PATRICK_OS_HOME/openclaw/audit.log
#
# Formato por línea:
#   YYYY-MM-DD HH:MM:SS | event=<evento> | mode=<modo> | result=<ok|blocked|fail|info> | detail=<texto>

set -uo pipefail

OS_HOME="${PATRICK_OS_HOME:-$HOME/.patrick-os}"
AUDIT_FILE="$OS_HOME/openclaw/audit.log"

cmd="${1:-tail}"

case "$cmd" in
    path)
        echo "$AUDIT_FILE"
        ;;
    list)
        if [ ! -f "$AUDIT_FILE" ]; then
            echo "Sin audit log ($AUDIT_FILE)."
            exit 0
        fi
        cat "$AUDIT_FILE"
        ;;
    tail)
        if [ ! -f "$AUDIT_FILE" ]; then
            echo "Sin audit log ($AUDIT_FILE)."
            exit 0
        fi
        # Últimas 20 entradas. El archivo es append-only así que
        # tail = más recientes.
        tail -n 20 "$AUDIT_FILE"
        ;;
    summary)
        if [ ! -f "$AUDIT_FILE" ]; then
            echo "Sin audit log."
            exit 0
        fi
        echo "OpenClaw Audit Summary"
        echo "Archivo: $AUDIT_FILE"
        echo
        # Catálogo fijo: orden estable, muestra ceros para eventos que
        # no ocurrieron, así el operador ve el shape completo de un
        # vistazo. grep -F es fixed-string (los '|' del separador son
        # literales); -c devuelve "0" cuando no hay matches, no rompe
        # con set -u.
        for ev in kill unkill run_allowed run_blocked_kill_switch \
                  run_blocked_policy run_invalid_mode run_empty_task \
                  execute_blocked_beta0 execute_blocked_kill_switch \
                  execute_blocked_policy execute_missing_approval \
                  status policy; do
            n=$(grep -cF "| event=$ev |" "$AUDIT_FILE")
            echo "event=$ev count=$n"
        done
        ;;
    *)
        echo "Uso: $0 {list|tail|path|summary}" >&2
        exit 1
        ;;
esac
