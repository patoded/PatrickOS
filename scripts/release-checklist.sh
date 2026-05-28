#!/usr/bin/env bash
# release-checklist.sh — Chequeo rápido pre-release.
# Reporta OK/TODO por ítem. Nunca aborta; el operador decide si publica.

echo "PatrickOS — Release checklist"
echo

todo_count=0
ok()   { echo "[OK]   $1"; }
todo() { echo "[TODO] $1"; todo_count=$((todo_count + 1)); }

# Resolver root del repo. Cuando el script está instalado en
# /usr/local/share/patrick-os/scripts/ el repo no existe localmente; en
# ese caso usamos el cwd y dejamos que los checks fallen como [TODO].
script_dir="$(cd "$(dirname "$0")" && pwd)"
case "$script_dir" in
    /usr/local/share/*) repo_dir="$(pwd)" ;;
    *)                  repo_dir="$(dirname "$script_dir")" ;;
esac

# 1) git status limpio.
if [ -d "$repo_dir/.git" ]; then
    if (cd "$repo_dir" && git diff --quiet && git diff --cached --quiet); then
        ok "git status limpio en $repo_dir"
    else
        todo "git status sucio en $repo_dir (commit o stash antes de tagear)"
    fi
else
    todo "no es un repo git ($repo_dir)"
fi

# 2) ISO presente.
iso="$repo_dir/iso/patrick-os-alpha.iso"
if [ -f "$iso" ]; then
    ok "ISO presente: $iso ($(du -h "$iso" 2>/dev/null | cut -f1))"
else
    todo "ISO faltante: $iso (corré sudo bash iso/build.sh)"
fi

# 3) SHA256 de la ISO.
sha="$iso.sha256"
if [ -f "$sha" ]; then
    ok "SHA256 presente: $sha"
else
    todo "SHA256 faltante: $sha  (sha256sum \"$iso\" > \"$sha\")"
fi

# 4) Tag git que coincida con _VERSION de Watson.
version=$(grep -E '^_VERSION' "$repo_dir/watson/watson.py" 2>/dev/null \
            | head -1 | sed 's/.*"\(.*\)".*/\1/')
version="${version:-v0.2.0-dev}"
if [ -d "$repo_dir/.git" ] && (cd "$repo_dir" && git rev-parse "$version" >/dev/null 2>&1); then
    ok "git tag presente: $version"
else
    todo "git tag faltante: $version  (git -C \"$repo_dir\" tag $version)"
fi

# 5) Release notes.
notes="$repo_dir/docs/RELEASE-$version.md"
if [ -f "$notes" ]; then
    ok "release notes: $notes"
else
    todo "release notes faltantes: $notes"
fi

echo
echo "Pendientes: $todo_count"
if [ "$todo_count" -gt 0 ]; then
    echo "Resuelve los [TODO] antes de publicar."
fi
exit 0
