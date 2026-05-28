#!/usr/bin/env bash
# new-branch.sh — crea una rama nueva desde main al día.
# Uso:  scripts/new-branch.sh feat/algo
set -euo pipefail

if [ $# -lt 1 ] || [ -z "${1:-}" ]; then
    echo "Uso: scripts/new-branch.sh <nombre-de-rama>" >&2
    echo "Ej.: scripts/new-branch.sh feat/ollama-cache" >&2
    exit 1
fi

branch="$1"

git checkout main
git pull --ff-only
git checkout -b "$branch"
echo
echo "Rama '$branch' creada desde main al día."
