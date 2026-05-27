#!/usr/bin/env bash
# install.sh — Instala Watson y sus scripts en el sistema.
#
# Watson queda en:    /usr/local/bin/watson
# Scripts quedan en:  /usr/local/share/patrick-os/scripts/
#
# Requiere privilegios de root (típicamente vía sudo).
# Uso: sudo bash scripts/install.sh

set -e

BIN_DIR="/usr/local/bin"
SHARE_DIR="/usr/local/share/patrick-os"
SCRIPTS_DEST="$SHARE_DIR/scripts"

if [ "$(id -u)" -ne 0 ]; then
    echo "Error: este script necesita privilegios de root."
    echo "Ejecuta:  sudo bash scripts/install.sh"
    exit 1
fi

# Resolvemos la raíz del repo a partir de la ubicación del propio script.
script_dir="$(cd "$(dirname "$0")" && pwd)"
repo_dir="$(dirname "$script_dir")"

if [ ! -f "$repo_dir/watson/watson.py" ]; then
    echo "Error: no encuentro watson/watson.py en $repo_dir."
    exit 1
fi

echo "Instalando Watson desde:  $repo_dir"
echo "Destino binario:          $BIN_DIR/watson"
echo "Destino scripts:          $SCRIPTS_DEST"
echo

# 1) Copiar watson.py a /usr/local/bin/watson con permisos ejecutables.
install -m 0755 "$repo_dir/watson/watson.py" "$BIN_DIR/watson"

# 2) Copiar todos los scripts a /usr/local/share/patrick-os/scripts/.
mkdir -p "$SCRIPTS_DEST"
install -m 0755 "$repo_dir/scripts/"*.sh "$SCRIPTS_DEST/"

# 3) Ajustar el SCRIPTS_DIR por defecto en la copia instalada.
# El watson original busca '../scripts' relativo a __file__; tras instalar a
# /usr/local/bin/, ese cálculo apunta a /usr/local/scripts (incorrecto).
# Sustituimos la línea para que apunte al destino real. La variable de entorno
# PATRICK_OS_SCRIPTS sigue funcionando como override en runtime.
sed -i "s|^_DEFAULT_SCRIPTS_DIR = .*|_DEFAULT_SCRIPTS_DIR = pathlib.Path(\"$SCRIPTS_DEST\")|" "$BIN_DIR/watson"

echo "Watson instalado."
echo "Pruébalo con:  watson"
