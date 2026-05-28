#!/usr/bin/env bash
# pr-merge.sh — mergea el PR (squash) y vuelve a main limpio.
# Uso:
#   scripts/pr-merge.sh           # mergea el PR de la rama actual
#   scripts/pr-merge.sh 42        # mergea el PR #42
set -euo pipefail

if ! command -v gh >/dev/null 2>&1; then
    echo "ERROR: gh CLI no está instalado." >&2
    exit 1
fi

# Resolver número de PR antes de cambiar de rama: si no se pasa, gh lo
# infiere de la rama actual; si después saltamos a main, esa inferencia
# ya no funciona.
pr="${1:-}"
if [ -z "$pr" ]; then
    if ! pr="$(gh pr view --json number --jq .number 2>/dev/null)"; then
        echo "ERROR: no hay PR asociado a la rama actual y no se pasó número." >&2
        echo "       Uso: scripts/pr-merge.sh [<numero_de_pr>]" >&2
        exit 1
    fi
fi

echo "Mergeando PR #$pr (squash + delete-branch)..."
# Cambiamos a main ANTES del merge para evitar el caso 'estoy parado en la
# rama que --delete-branch va a borrar'. El PR se identifica por número,
# así que no importa en qué rama estemos al invocar merge.
git checkout main
git pull --ff-only
gh pr merge "$pr" --squash --delete-branch

echo
echo "git status tras merge:"
git status
