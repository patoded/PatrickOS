#!/usr/bin/env bash
# check-installed-watson.sh — verifica que el Watson instalado
# globalmente está en sync con el repo. NO escribe nada, NO usa sudo;
# se puede correr en cualquier momento como diagnóstico ("¿está mi
# instalación al día?"). Es el mismo set de chequeos que hace install.sh
# al final, pero re-ejecutable contra un sistema ya instalado.
#
# Uso:
#   scripts/check-installed-watson.sh
#   make check-installed
#
# Reporta OK/FAIL por chequeo. Exit code = nº de FAILs (0 = todo OK).

set -uo pipefail

BIN_DIR="/usr/local/bin"
SHARE_DIR="/usr/local/share/patrick-os"
SCRIPTS_DEST="$SHARE_DIR/scripts"
DOCS_DEST="$SHARE_DIR/docs"
CONFIGS_DEST="$SHARE_DIR/configs"

CRITICAL_SCRIPTS=(
    home.sh
    daily.sh
    notes.sh
    todos.sh
    workspace.sh
    openclaw-stub.sh
    openclaw-policy.sh
    openclaw-audit.sh
    openclaw-tools.sh
    openclaw-contracts.sh
    openclaw-negative-tests.sh
    openclaw-simulate-tool.sh
    validate-system.sh
    doctor.sh
)

# Docs cuya presencia post-install consideramos contrato. ask-local.sh
# usa README/ARCHITECTURE como contexto; PROJECT_CONTEXT es el manifiesto
# vivo del proyecto. Otros .md también se copian, pero estos son los
# críticos.
CRITICAL_DOCS=(
    README.md
    ARCHITECTURE.md
    PROJECT_CONTEXT.md
)

# Configs cuya presencia post-install es contrato (los lee el runtime).
CRITICAL_CONFIGS=(
    openclaw-policy.yaml
    openclaw-tools.yaml
)

script_dir="$(cd "$(dirname "$0")" && pwd)"
repo_dir="$(dirname "$script_dir")"

fail=0
ok()       { echo "[OK]   $1"; }
report_fail() { echo "[FAIL] $1"; fail=$((fail + 1)); }

echo "PatrickOS / Watson — verificación de instalación global"
echo "Repo:     $repo_dir"
echo

# 1) Watson en PATH y ubicación.
watson_path="$(command -v watson 2>/dev/null || true)"
if [ -z "$watson_path" ]; then
    report_fail "watson no está en PATH (¿corriste 'sudo bash scripts/install.sh'?)"
else
    ok "watson en PATH: $watson_path"
fi

# 2) Versiones coinciden.
repo_version="$(python3 "$repo_dir/watson/watson.py" version 2>/dev/null || true)"
inst_version=""
if [ -n "$watson_path" ]; then
    inst_version="$("$watson_path" version 2>/dev/null || true)"
fi
if [ -z "$repo_version" ]; then
    report_fail "no pude leer la versión del repo ($repo_dir/watson/watson.py)"
elif [ -z "$inst_version" ]; then
    report_fail "no pude leer la versión instalada"
elif [ "$repo_version" != "$inst_version" ]; then
    report_fail "versión instalada distinta a la del repo"
    echo "  --- repo ---"; echo "$repo_version" | sed 's/^/    /'
    echo "  --- inst ---"; echo "$inst_version" | sed 's/^/    /'
else
    ok "versión instalada coincide con el repo"
fi

# 3) Scripts críticos: existen, +x, y su contenido coincide con el repo.
# El contenido se compara byte-a-byte con cmp; cualquier diferencia
# (incluso un \n extra) marca el script como desactualizado.
if [ ! -d "$SCRIPTS_DEST" ]; then
    report_fail "$SCRIPTS_DEST no existe"
else
    ok "scripts dir presente: $SCRIPTS_DEST"
fi
for s in "${CRITICAL_SCRIPTS[@]}"; do
    src="$repo_dir/scripts/$s"
    dst="$SCRIPTS_DEST/$s"
    if [ ! -f "$dst" ]; then
        report_fail "script ausente: $dst"
        continue
    fi
    if [ ! -x "$dst" ]; then
        report_fail "script sin +x: $dst"
        continue
    fi
    if [ ! -f "$src" ]; then
        report_fail "script faltante en el repo: $src"
        continue
    fi
    if ! cmp -s "$src" "$dst"; then
        report_fail "script desactualizado: $dst (≠ $src)"
        continue
    fi
    ok "script en sync: $s"
done

# 4) Docs críticos: existen y coinciden con el repo.
if [ ! -d "$DOCS_DEST" ]; then
    report_fail "$DOCS_DEST no existe"
else
    ok "docs dir presente: $DOCS_DEST"
fi
for d in "${CRITICAL_DOCS[@]}"; do
    src="$repo_dir/docs/$d"
    dst="$DOCS_DEST/$d"
    if [ ! -f "$dst" ]; then
        report_fail "doc ausente: $dst"
        continue
    fi
    if [ ! -f "$src" ]; then
        report_fail "doc faltante en el repo: $src"
        continue
    fi
    if ! cmp -s "$src" "$dst"; then
        report_fail "doc desactualizado: $dst (≠ $src)"
        continue
    fi
    ok "doc en sync: $d"
done

# 5) Configs críticos: existen y coinciden con el repo.
if [ ! -d "$CONFIGS_DEST" ]; then
    report_fail "$CONFIGS_DEST no existe"
else
    ok "configs dir presente: $CONFIGS_DEST"
fi
for c in "${CRITICAL_CONFIGS[@]}"; do
    src="$repo_dir/configs/$c"
    dst="$CONFIGS_DEST/$c"
    if [ ! -f "$dst" ]; then
        report_fail "config ausente: $dst"
        continue
    fi
    if [ ! -f "$src" ]; then
        report_fail "config faltante en el repo: $src"
        continue
    fi
    if ! cmp -s "$src" "$dst"; then
        report_fail "config desactualizado: $dst (≠ $src)"
        continue
    fi
    ok "config en sync: $c"
done

echo
if [ "$fail" -gt 0 ]; then
    echo "Resultado: FAIL ($fail problema/s). Sugerencia: sudo bash scripts/install.sh"
    exit 1
fi
echo "Resultado: OK. Instalación global en sync con el repo."
exit 0
