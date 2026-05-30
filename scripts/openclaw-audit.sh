#!/usr/bin/env bash
# openclaw-audit.sh — lectura del audit log estructurado de OpenClaw.
# NO escribe el log (el escritor es openclaw-stub.sh), NO ejecuta nada,
# NO toca red. Solo formatos de lectura.
#
# Uso:
#   openclaw-audit.sh path     imprime ruta del audit.log
#   openclaw-audit.sh list     imprime el log completo (oldest first)
#   openclaw-audit.sh tail     imprime las últimas 20 entradas (default)
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
    *)
        echo "Uso: $0 {list|tail|path}" >&2
        exit 1
        ;;
esac
