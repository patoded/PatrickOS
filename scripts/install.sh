#!/usr/bin/env bash
# install.sh — Instala Watson y sus scripts en el sistema y verifica
# que la instalación quedó en sync con el repo. Si algo falla la
# verificación post-install, abortamos con exit 1 para que un Watson
# global viejo nunca conviva con un repo nuevo sin que lo notes.
#
# Watson queda en:    /usr/local/bin/watson
# Scripts quedan en:  /usr/local/share/patrick-os/scripts/
# Docs quedan en:     /usr/local/share/patrick-os/docs/
#
# Requiere root (típicamente vía sudo).
# Uso: sudo bash scripts/install.sh

set -euo pipefail

BIN_DIR="/usr/local/bin"
SHARE_DIR="/usr/local/share/patrick-os"
SCRIPTS_DEST="$SHARE_DIR/scripts"
DOCS_DEST="$SHARE_DIR/docs"
CONFIGS_DEST="$SHARE_DIR/configs"

# Configs cuya ausencia tras instalar es bug: openclaw-stub.sh aborta
# si no encuentra la policy, así que mejor verificarlo aquí.
CRITICAL_CONFIGS=(
    openclaw-policy.yaml
    openclaw-tools.yaml
)

# Scripts cuya ausencia tras instalar es bug crítico: backend de comandos
# Watson que el usuario va a invocar de inmediato.
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
    validate-system.sh
    doctor.sh
)

if [ "$(id -u)" -ne 0 ]; then
    echo "Error: este script necesita privilegios de root."
    echo "Ejecuta:  sudo bash scripts/install.sh"
    exit 1
fi

script_dir="$(cd "$(dirname "$0")" && pwd)"
repo_dir="$(dirname "$script_dir")"

if [ ! -f "$repo_dir/watson/watson.py" ]; then
    echo "Error: no encuentro watson/watson.py en $repo_dir."
    exit 1
fi

echo "Instalando Watson desde:  $repo_dir"
echo "Destino binario:          $BIN_DIR/watson"
echo "Destino scripts:          $SCRIPTS_DEST"
echo "Destino docs:             $DOCS_DEST"
echo "Destino configs:          $CONFIGS_DEST"
echo

# 1) Copiar watson.py a /usr/local/bin/watson con permisos ejecutables.
install -m 0755 "$repo_dir/watson/watson.py" "$BIN_DIR/watson"

# 2) Copiar todos los scripts a /usr/local/share/patrick-os/scripts/.
mkdir -p "$SCRIPTS_DEST"
install -m 0755 "$repo_dir/scripts/"*.sh "$SCRIPTS_DEST/"

# 3) Copiar todos los .md de docs/. Antes solo se copiaban README y
# ARCHITECTURE; ahora arrastramos el resto (PROJECT_CONTEXT, V0.3_PLAN,
# OPENCLAW_BETA0_SPEC, release notes, etc.) para que la copia global
# refleje el repo.
mkdir -p "$DOCS_DEST"
install -m 0644 "$repo_dir/docs/"*.md "$DOCS_DEST/"

# 3b) Copiar configs/*.yaml. Hoy solo openclaw-policy.yaml; cuando
# aparezcan más se incluyen sin tocar este código.
mkdir -p "$CONFIGS_DEST"
install -m 0644 "$repo_dir/configs/"*.yaml "$CONFIGS_DEST/"

# 4) Ajustar el SCRIPTS_DIR por defecto en la copia instalada.
# El watson original busca '../scripts' relativo a __file__; tras instalar a
# /usr/local/bin/, ese cálculo apunta a /usr/local/scripts (incorrecto).
# Sustituimos la línea para que apunte al destino real. La variable de entorno
# PATRICK_OS_SCRIPTS sigue funcionando como override en runtime.
sed -i "s|^_DEFAULT_SCRIPTS_DIR = .*|_DEFAULT_SCRIPTS_DIR = pathlib.Path(\"$SCRIPTS_DEST\")|" "$BIN_DIR/watson"

# 5) Verificación post-install. Cualquier falla = exit 1. La idea es que
# nunca termines con un /usr/local/bin/watson viejo respecto al repo
# sin enterarte.
echo
echo "Verificación post-install:"

fail=0
report_fail() { echo "  [FAIL] $1"; fail=$((fail + 1)); }
report_ok()   { echo "  [OK]   $1"; }

# Watson global existe y es ejecutable.
if [ ! -x "$BIN_DIR/watson" ]; then
    report_fail "$BIN_DIR/watson no es ejecutable"
else
    report_ok "$BIN_DIR/watson instalado (+x)"
fi

# Versiones coinciden. Comparamos el output completo de 'version' (3
# líneas) — basta con que difiera una para fallar.
repo_version="$(python3 "$repo_dir/watson/watson.py" version 2>/dev/null || true)"
inst_version="$("$BIN_DIR/watson" version 2>/dev/null || true)"
if [ -z "$repo_version" ]; then
    report_fail "no pude leer la versión del repo"
elif [ -z "$inst_version" ]; then
    report_fail "no pude leer la versión instalada"
elif [ "$repo_version" != "$inst_version" ]; then
    report_fail "versión instalada distinta a la del repo"
    echo "  --- repo ---"; echo "$repo_version" | sed 's/^/    /'
    echo "  --- inst ---"; echo "$inst_version" | sed 's/^/    /'
else
    report_ok "versión instalada coincide con el repo"
fi

# Scripts críticos: existen y son +x en el destino.
for s in "${CRITICAL_SCRIPTS[@]}"; do
    dst="$SCRIPTS_DEST/$s"
    if [ ! -f "$dst" ]; then
        report_fail "$dst no existe"
    elif [ ! -x "$dst" ]; then
        report_fail "$dst no es ejecutable"
    else
        report_ok "$s instalado (+x)"
    fi
done

# Configs críticos: existen en el destino (no se exige +x, son data).
for c in "${CRITICAL_CONFIGS[@]}"; do
    dst="$CONFIGS_DEST/$c"
    if [ ! -f "$dst" ]; then
        report_fail "$dst no existe"
    else
        report_ok "$c instalado"
    fi
done

echo
if [ "$fail" -gt 0 ]; then
    echo "Instalación FALLÓ con $fail problema(s). Revisá el output arriba."
    exit 1
fi

echo "Watson instalado y verificado."
echo "Pruébalo con:  watson"
