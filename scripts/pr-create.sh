#!/usr/bin/env bash
set -euo pipefail

BASE="${1:-main}"
TITLE="${2:-}"
BODY_FILE="${3:-}"

BRANCH="$(git branch --show-current)"

if [ "$BRANCH" = "$BASE" ]; then
  echo "ERROR: estás en $BASE. Crea una rama primero."
  exit 1
fi

if [ -z "$TITLE" ]; then
  echo "Uso: scripts/pr-create.sh <base> <titulo> [body_file]"
  exit 1
fi

git status --short
git push -u origin "$BRANCH"

if [ -n "$BODY_FILE" ] && [ -f "$BODY_FILE" ]; then
  gh pr create --base "$BASE" --head "$BRANCH" --title "$TITLE" --body-file "$BODY_FILE"
else
  gh pr create --base "$BASE" --head "$BRANCH" --title "$TITLE" --body "$TITLE"
fi
