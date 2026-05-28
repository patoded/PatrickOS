#!/usr/bin/env bash
# dev-check.sh — pasada rápida pre-PR: lint + parse + smoke de Watson.
# No 'set -e' a propósito: queremos correr todos los chequeos aunque
# alguno falle, y reportar al final cuántos fallaron. Exit = nº de fails.

# Resolver repo root desde la ubicación del script (no depende del cwd).
script_dir="$(cd "$(dirname "$0")" && pwd)"
repo_dir="$(dirname "$script_dir")"
cd "$repo_dir"

fail_count=0
run() {
    local label="$1"; shift
    echo
    echo "=== $label ==="
    if "$@"; then
        echo "  [OK]   $label"
    else
        echo "  [FAIL] $label"
        fail_count=$((fail_count + 1))
    fi
}

run "py_compile watson.py" python3 -m py_compile watson/watson.py

run "bash -n scripts/*.sh" bash -c '
    fails=0
    for f in scripts/*.sh; do
        if ! bash -n "$f"; then fails=$((fails+1)); fi
    done
    exit "$fails"
'

run "make test" make test
run "watson estado"  python3 watson/watson.py estado
run "watson version" python3 watson/watson.py version

# validar necesita PATRICK_OS_SCRIPTS apuntando al repo para encontrar
# los .sh sin estar instalado en /usr/local. Reuse el repo_dir resuelto.
run "watson validar" env "PATRICK_OS_SCRIPTS=$repo_dir/scripts" \
    python3 watson/watson.py validar

echo
echo "==============================="
echo "dev-check: fails=$fail_count"
echo "==============================="
exit "$fail_count"
