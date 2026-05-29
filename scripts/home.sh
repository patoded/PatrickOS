#!/usr/bin/env bash
# home.sh — panel rápido tipo "home" de WatsonOS. Solo lee estado local,
# no toca red, no carga modelos. Pensado como primer comando del día.
#
# Uso:
#   scripts/home.sh
#
# Secciones:
#   Estado Watson  — versión de Watson CLI.
#   Sistema        — hostname / uptime / memoria.
#   Daily          — delega en daily.sh si está presente y ejecutable.
#   Atajos         — recordatorio de comandos comunes.
#
# Overrides reconocidos (los respeta daily.sh, los enumeramos acá para que
# correr este script con sandbox funcione idéntico al resto):
#   PATRICK_OS_NOTES_DIR
#   PATRICK_OS_TODOS_DIR

# No 'set -e' a propósito: cada sección es independiente. Si uptime no
# está, no quiero que se caiga la sección Atajos.

script_dir="$(cd "$(dirname "$0")" && pwd)"
repo_dir="$(dirname "$script_dir")"

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
echo "Daily:"
daily_script="$script_dir/daily.sh"
if [ -x "$daily_script" ]; then
    # daily.sh ya respeta PATRICK_OS_NOTES_DIR / PATRICK_OS_TODOS_DIR, así
    # que heredamos el env tal cual.
    "$daily_script"
else
    echo "daily.sh no disponible (se shippea con PR #14)."
fi

echo
echo "Atajos:"
echo "  watson nota \"texto\"   guarda nota rápida"
echo "  watson tarea \"texto\"  agrega tarea pendiente"
echo "  watson diario         resumen del día"
echo "  watson ia             chequeo de Ollama/GPU"
echo "  watson claw           OpenClaw stub"
