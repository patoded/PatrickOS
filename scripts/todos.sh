#!/usr/bin/env bash
# todos.sh — captura y gestión simple de tareas locales.
# Uso:
#   scripts/todos.sh add "texto de la tarea"
#   scripts/todos.sh list
#   scripts/todos.sh done <numero>
#
# Almacenamiento por default en ~/.patrick-os/todos/todos.md.
# Override para tests / sandbox: PATRICK_OS_TODOS_DIR=/tmp/todos ./todos.sh add ...
#
# Formato por línea:
#   - [ ] YYYY-MM-DD HH:MM:SS | texto    (pendiente)
#   - [x] YYYY-MM-DD HH:MM:SS | texto    (completada)
#
# El número de tarea que usa 'done <n>' corresponde al número de línea
# del archivo (1-indexed), que es el mismo que muestra 'list' al
# principio de cada renglón. Eso lo hace estable aunque list trunque a
# las últimas 30.

set -euo pipefail

TODOS_DIR="${PATRICK_OS_TODOS_DIR:-$HOME/.patrick-os/todos}"
TODOS_FILE="$TODOS_DIR/todos.md"

usage() {
    cat <<'EOF'
Uso:
  todos.sh add "texto de la tarea"
  todos.sh list
  todos.sh done <numero>
EOF
}

cmd="${1:-}"
shift || true

case "$cmd" in
    add)
        texto="${*:-}"
        # Trim blancos al inicio/fin.
        texto="${texto#"${texto%%[![:space:]]*}"}"
        texto="${texto%"${texto##*[![:space:]]}"}"
        if [ -z "$texto" ]; then
            echo "Error: texto vacío. No se guardó tarea." >&2
            usage >&2
            exit 1
        fi
        mkdir -p "$TODOS_DIR"
        printf -- '- [ ] %s | %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$texto" >> "$TODOS_FILE"
        # Devolvemos el número con el que el usuario podrá hacer 'done'.
        n=$(wc -l < "$TODOS_FILE" | tr -d ' ')
        echo "Tarea #$n guardada en $TODOS_FILE"
        ;;
    list)
        if [ ! -f "$TODOS_FILE" ]; then
            echo "Sin tareas."
            exit 0
        fi
        # Numerar 1..N todas las líneas (incluso las ya-done), mostrar
        # solo las últimas 30. Los números son estables — el que vea
        # el usuario al final es el que usa con 'done'.
        awk 'BEGIN{n=0} {n++; lines[n]=$0} END {
            start = (n > 30) ? n - 29 : 1
            for (i = start; i <= n; i++) printf "%d. %s\n", i, lines[i]
        }' "$TODOS_FILE"
        ;;
    done)
        n="${1:-}"
        if [ -z "$n" ]; then
            echo "Error: 'done' espera un número." >&2
            usage >&2
            exit 1
        fi
        if ! [[ "$n" =~ ^[0-9]+$ ]]; then
            echo "Error: 'done' espera un número entero. Recibido: '$n'." >&2
            exit 1
        fi
        if [ ! -f "$TODOS_FILE" ]; then
            echo "Error: no hay archivo de tareas todavía." >&2
            exit 1
        fi
        total=$(wc -l < "$TODOS_FILE" | tr -d ' ')
        if [ "$n" -lt 1 ] || [ "$n" -gt "$total" ]; then
            echo "Error: tarea $n fuera de rango (1..$total)." >&2
            exit 1
        fi
        # Toggle solo si la línea está pendiente. Si ya está [x], lo
        # decimos y salimos limpio para que llamadas idempotentes no
        # asusten.
        line=$(sed -n "${n}p" "$TODOS_FILE")
        if [[ "$line" == "- [x]"* ]]; then
            echo "Tarea $n ya estaba completada: $line"
            exit 0
        fi
        # sed -i: reemplaza el prefijo "- [ ]" por "- [x]" en la línea n.
        sed -i "${n}s/^- \[ \]/- [x]/" "$TODOS_FILE"
        echo "Tarea $n marcada como completada: $(sed -n "${n}p" "$TODOS_FILE")"
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
