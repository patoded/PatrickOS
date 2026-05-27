#!/usr/bin/env bash
# build.sh — Construye la ISO Alpha de PatrickOS con live-build.
# Resultado:  iso/patrick-os-alpha.iso
#
# Requisitos:  live-build instalado, privilegios sudo, ~10 GB libres en /.
# Tiempo:      20-40 minutos en hardware moderno con buena red.
#
# Uso:         sudo bash iso/build.sh

set -e

# Rutas relativas al propio script (no al cwd).
script_dir="$(cd "$(dirname "$0")" && pwd)"
repo_dir="$(dirname "$script_dir")"
config_dir="$script_dir/config"
includes_dir="$config_dir/includes.chroot"

OUT_ISO="$script_dir/patrick-os-alpha.iso"

echo "=== PatrickOS ISO builder ==="
echo "Repo:    $repo_dir"
echo "Build:   $script_dir"
echo "Output:  $OUT_ISO"
echo

# 0) Pre-flight: live-build instalado.
if ! command -v lb >/dev/null 2>&1; then
    echo "Error: live-build no está instalado."
    echo "Instálalo con:  sudo apt install live-build"
    exit 1
fi

# 0) Pre-flight: aviso si estamos en WSL2 (live-build aquí es frágil).
if uname -a | grep -qi microsoft; then
    echo "Aviso: detectado WSL2. live-build dentro de WSL2 puede fallar por"
    echo "       limitaciones de cgroups, mount o binfmt_misc. Si falla,"
    echo "       construye en una VM Linux nativa o un contenedor Docker."
    echo
fi

# 1) Poblar includes.chroot con Watson + scripts + docs.
echo "[1/4] Copiando Watson, scripts y docs a includes.chroot..."

WATSON_DEST="$includes_dir/usr/local/bin/watson"
SCRIPTS_DEST="$includes_dir/usr/local/share/patrick-os/scripts"
DOCS_DEST="$includes_dir/usr/local/share/patrick-os/docs"

mkdir -p "$(dirname "$WATSON_DEST")" "$SCRIPTS_DEST" "$DOCS_DEST"

cp "$repo_dir/watson/watson.py" "$WATSON_DEST"
# Ajustar SCRIPTS_DIR de la copia instalada a la ruta del sistema.
# (PATRICK_OS_SCRIPTS sigue funcionando como override en runtime.)
sed -i 's|^_DEFAULT_SCRIPTS_DIR = .*|_DEFAULT_SCRIPTS_DIR = pathlib.Path("/usr/local/share/patrick-os/scripts")|' "$WATSON_DEST"
chmod +x "$WATSON_DEST"

cp "$repo_dir/scripts/"*.sh "$SCRIPTS_DEST/"
chmod +x "$SCRIPTS_DEST"/*.sh

cp "$repo_dir/docs/README.md" "$DOCS_DEST/"
cp "$repo_dir/docs/ARCHITECTURE.md" "$DOCS_DEST/"

echo "    Listo."

# 2) lb clean si hay un build previo.
echo "[2/4] lb clean..."
cd "$script_dir"
if [ -d chroot ] || [ -d binary ] || [ -d .build ]; then
    lb clean
else
    echo "    (sin build previo, nada que limpiar)"
fi

# 3) lb config: aplica auto/config.
echo "[3/4] lb config..."
lb config

# 4) lb build: construye la ISO.
echo "[4/4] lb build (20-40 minutos, requiere red)..."
lb build

# Renombrar al nombre del proyecto.
if [ -f "live-image-amd64.hybrid.iso" ]; then
    mv live-image-amd64.hybrid.iso "$OUT_ISO"
    echo
    echo "Listo: $OUT_ISO"
    ls -lh "$OUT_ISO"
else
    echo "Error: no se generó live-image-amd64.hybrid.iso."
    echo "Revisa los logs en $script_dir/binary.log y $script_dir/chroot.log"
    exit 1
fi
