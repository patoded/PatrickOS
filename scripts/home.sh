#!/usr/bin/env bash
# home.sh — panel rápido tipo "home" de WatsonOS. Solo lee estado local,
# no toca red, no carga modelos. Pensado como primer comando del día.
#
# Uso:
#   scripts/home.sh
#
# Secciones:
#   Estado Watson    — versión de Watson CLI.
#   Sistema          — hostname / uptime / memoria.
#   Notas recientes  — últimas líneas de ~/.patrick-os/notes/notes.md.
#   Tareas pendientes — pendientes ("- [ ]") de ~/.patrick-os/todos/todos.md.
#   Atajos           — recordatorio de comandos comunes.
#
# Overrides reconocidos (compartidos con notes.sh / todos.sh / daily.sh):
#   PATRICK_OS_NOTES_DIR
#   PATRICK_OS_TODOS_DIR

# No 'set -e' a propósito: cada sección es independiente. Si uptime no
# está, no quiero que se caiga la sección Atajos.

script_dir="$(cd "$(dirname "$0")" && pwd)"
repo_dir="$(dirname "$script_dir")"

NOTES_FILE="${PATRICK_OS_NOTES_DIR:-$HOME/.patrick-os/notes}/notes.md"
TODOS_FILE="${PATRICK_OS_TODOS_DIR:-$HOME/.patrick-os/todos}/todos.md"

echo "PatrickOS Home"

echo
echo "Estado Watson:"
# Preferimos delegar en watson.py para que la versión salga del único
# lugar donde se define (_VERSION). Si no podemos invocarlo, caemos a un
# texto fijo para no romper el panel.
if command -v python3 >/dev/null 2>&1 && [ -f "$repo_dir/watson/watson.py" ]; then
    python3 "$repo_dir/watson/watson.py" version 2>/dev/null || echo "Watson CLI (no se pudo leer versión)"
else
    echo "Watson CLI (python3/watson.py no disponible)"
fi

echo
echo "Sistema:"
echo "hostname: $(hostname 2>/dev/null || echo desconocido)"
if command -v uptime >/dev/null 2>&1; then
    # uptime -p es GNU; si no está soportada (BSD/macOS), caemos a uptime plano.
    up="$(uptime -p 2>/dev/null || uptime 2>/dev/null || true)"
    echo "uptime: ${up:-desconocido}"
else
    echo "uptime: no disponible"
fi
if command -v free >/dev/null 2>&1; then
    # free -h: 1ª línea = header, 2ª = Mem. Mostramos ambas para que el
    # usuario vea total/used/avail sin abrir otro shell.
    free -h 2>/dev/null | head -n 2
else
    echo "memoria: free no disponible"
fi

echo
echo "Notas recientes:"
if [ -f "$NOTES_FILE" ]; then
    # Append-only, así que tail = más recientes. 5 líneas para que el
    # panel siga cabiendo en una pantalla cómoda.
    tail -n 5 "$NOTES_FILE"
else
    echo "Sin notas."
fi

echo
echo "Tareas pendientes:"
if [ -f "$TODOS_FILE" ]; then
    # Pendientes = prefijo "- [ ]". A diferencia de daily.sh, no
    # filtramos por fecha: lo arrastrado de días previos también cuenta.
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
echo "Atajos:"
echo "  watson dev       entorno de desarrollo"
echo "  watson ia        chequeo de Ollama/GPU"
echo "  watson consulta  modo consulta clínica"
echo "  watson clase     modo docente"
echo "  watson video     modo edición de video"
echo "  watson diario    resumen del día"
echo "  watson tareas    lista de tareas"
echo "  watson notas     lista de notas"
