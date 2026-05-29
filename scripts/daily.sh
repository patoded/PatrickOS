#!/usr/bin/env bash
# daily.sh — resumen diario local: notas de hoy + tareas pendientes +
# tareas completadas hoy. Solo lee archivos locales; no hace red.
#
# Uso:
#   scripts/daily.sh
#
# Fuentes (mismas que notes.sh / todos.sh):
#   ~/.patrick-os/notes/notes.md
#   ~/.patrick-os/todos/todos.md
# Overrides para tests / sandbox:
#   PATRICK_OS_NOTES_DIR=/tmp/notes
#   PATRICK_OS_TODOS_DIR=/tmp/todos
#
# Formato esperado en notes.md:
#   YYYY-MM-DD HH:MM:SS | texto
# Formato esperado en todos.md:
#   - [ ] YYYY-MM-DD HH:MM:SS | texto    (pendiente)
#   - [x] YYYY-MM-DD HH:MM:SS | texto    (completada)
#
# "Tareas completadas hoy" filtra por la fecha embebida en la línea (el
# timestamp de creación queda fijo al hacer 'done', así que el corte es
# sobre esa fecha; coincidiendo con notes.sh / todos.sh).

set -euo pipefail

NOTES_DIR="${PATRICK_OS_NOTES_DIR:-$HOME/.patrick-os/notes}"
TODOS_DIR="${PATRICK_OS_TODOS_DIR:-$HOME/.patrick-os/todos}"
NOTES_FILE="$NOTES_DIR/notes.md"
TODOS_FILE="$TODOS_DIR/todos.md"

TODAY="$(date '+%Y-%m-%d')"

echo "PatrickOS Daily"
echo "Fecha: $TODAY"

echo
echo "Notas de hoy:"
if [ -f "$NOTES_FILE" ]; then
    # Notas cuya línea arranca con la fecha de hoy. Append-only, así que
    # tail = más recientes.
    hoy_notas="$(grep -E "^${TODAY} " "$NOTES_FILE" || true)"
    if [ -n "$hoy_notas" ]; then
        echo "$hoy_notas" | tail -n 10
    else
        echo "Sin notas de hoy."
    fi
else
    echo "Sin notas de hoy."
fi

echo
echo "Tareas pendientes:"
if [ -f "$TODOS_FILE" ]; then
    # Pendientes = prefijo "- [ ]". El timestamp puede ser de cualquier
    # día (las pendientes que arrastrás de ayer también cuentan).
    pendientes="$(grep -E '^- \[ \] ' "$TODOS_FILE" || true)"
    if [ -n "$pendientes" ]; then
        echo "$pendientes" | tail -n 10
    else
        echo "Sin tareas pendientes."
    fi
else
    echo "Sin tareas pendientes."
fi

echo
echo "Tareas completadas hoy:"
if [ -f "$TODOS_FILE" ]; then
    completadas_hoy="$(grep -E "^- \[x\] ${TODAY} " "$TODOS_FILE" || true)"
    if [ -n "$completadas_hoy" ]; then
        echo "$completadas_hoy" | tail -n 10
    else
        echo "Sin tareas completadas hoy."
    fi
else
    echo "Sin tareas completadas hoy."
fi
