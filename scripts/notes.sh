#!/usr/bin/env bash
# notes.sh — captura y lista de notas rápidas locales.
# Uso:
#   scripts/notes.sh add "texto de la nota"
#   scripts/notes.sh list
#
# Almacenamiento por default en ~/.patrick-os/notes/notes.md.
# Override para tests / sandbox: PATRICK_OS_NOTES_DIR=/tmp/notes ./notes.sh add ...

set -euo pipefail

NOTES_DIR="${PATRICK_OS_NOTES_DIR:-$HOME/.patrick-os/notes}"
NOTES_FILE="$NOTES_DIR/notes.md"

usage() {
    cat <<'EOF'
Uso:
  notes.sh add "texto de la nota"
  notes.sh list
EOF
}

cmd="${1:-}"
shift || true

case "$cmd" in
    add)
        # Junta todos los args restantes y recorta blancos al inicio/fin.
        texto="${*:-}"
        texto="${texto#"${texto%%[![:space:]]*}"}"
        texto="${texto%"${texto##*[![:space:]]}"}"
        if [ -z "$texto" ]; then
            echo "Error: texto vacío. No se guardó nota." >&2
            usage >&2
            exit 1
        fi
        mkdir -p "$NOTES_DIR"
        # Append una línea: "YYYY-MM-DD HH:MM:SS | texto".
        printf '%s | %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$texto" >> "$NOTES_FILE"
        echo "Nota guardada en $NOTES_FILE"
        ;;
    list)
        if [ ! -f "$NOTES_FILE" ]; then
            echo "Sin notas."
            exit 0
        fi
        # Últimas 20 notas. El archivo es append-only así que tail = más recientes.
        tail -n 20 "$NOTES_FILE"
        ;;
    "")
        usage >&2
        exit 1
        ;;
    *)
        echo "Subcomando desconocido: $cmd" >&2
        usage >&2
        exit 1
        ;;
esac
