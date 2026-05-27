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

# 0a) Pre-flight: live-build instalado.
if ! command -v lb >/dev/null 2>&1; then
    echo "Error: live-build no está instalado."
    echo "Instálalo con:  sudo apt install live-build"
    exit 1
fi

# 0b) Pre-flight: aviso si estamos en WSL2 (live-build aquí es frágil).
if uname -a | grep -qi microsoft; then
    echo "Aviso: detectado WSL2. live-build dentro de WSL2 puede fallar por"
    echo "       limitaciones de cgroups, mount o binfmt_misc. Si falla,"
    echo "       construye en una VM Linux nativa o un contenedor Docker."
    echo
fi

# 0c) Defensivo: asegurar +x en scripts que viajan en el repo y que git pudo
# haber perdido (edición vía rutas Windows, etc.). Sin +x, auto/config no se
# ejecuta y lb_config cae al default 'precise'.
chmod +x "$script_dir/auto/config" 2>/dev/null || true
chmod +x "$script_dir/config/hooks/normal/"*.hook.chroot 2>/dev/null || true

# 1) Poblar includes.chroot con Watson + scripts + docs.
echo "[1/6] Copiando Watson, scripts y docs a includes.chroot..."

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

cd "$script_dir"

# 2) lb clean si hay un build previo.
echo "[2/6] lb clean..."
if [ -d chroot ] || [ -d binary ] || [ -d .build ]; then
    lb clean
else
    echo "    (sin build previo, nada que limpiar)"
fi

# 3) Borrar config generada previa (puede contener 'precise' de runs anteriores).
# Solo borramos lo que produce lb_config; los archivos del usuario
# (auto/, config/package-lists/, config/hooks/, config/includes.chroot/) se quedan.
echo "[3/6] Limpiando config generada previa..."
rm -f config/binary config/bootstrap config/chroot config/common config/source
rm -rf config/archives config/binary_* config/chroot_apt config/includes config/includes.binary* config/packages config/packages.binary config/packages.chroot config/preseed config/templates
# Orphan: ubicación incorrecta de auto/config que quedó de un commit previo.
rm -rf config/auto

# 4) lb config — TODOS los parámetros explícitos, sin depender de auto/config.
# 'noauto' suprime la auto-ejecución de auto/config (que igual hace lo mismo,
# pero aquí blindamos el path).
echo "[4/6] lb config (parámetros explícitos)..."
lb config noauto \
    --mode ubuntu \
    --distribution noble \
    --archive-areas "main universe multiverse restricted" \
    --linux-flavours generic \
    --binary-images iso-hybrid \
    --debian-installer false \
    --apt-indices false \
    --memtest none \
    --bootappend-live "boot=live components quiet splash" \
    --iso-application "PatrickOS Alpha" \
    --iso-publisher "Patrick Mendoza" \
    --iso-volume "PatrickOS Alpha" \
    --mirror-bootstrap http://archive.ubuntu.com/ubuntu/ \
    --mirror-chroot http://archive.ubuntu.com/ubuntu/ \
    --mirror-binary http://archive.ubuntu.com/ubuntu/

# 5) Validación: bootstrap debe declarar noble y NUNCA precise.
echo "[5/6] Validando config/bootstrap..."
echo
echo "--- config/bootstrap (líneas clave) ---"
grep -E '^LB_(MODE|DISTRIBUTION|PARENT_DISTRIBUTION|ARCHIVE_AREAS|MIRROR_)' config/bootstrap config/common 2>/dev/null || true
echo "---"
echo

if ! grep -q '^LB_DISTRIBUTION="noble"' config/bootstrap; then
    echo "ERROR: LB_DISTRIBUTION no es 'noble' en config/bootstrap."
    grep '^LB_DISTRIBUTION=' config/bootstrap || true
    echo "Abortando antes de lb build."
    exit 1
fi

if grep -rln 'precise' config/ 2>/dev/null; then
    echo "ERROR: 'precise' detectado en config/ tras lb config."
    grep -rn 'precise' config/
    echo "Abortando antes de lb build."
    exit 1
fi

echo "    OK: distribución noble confirmada, sin rastro de precise."

# 6) lb build: construye la ISO.
echo "[6/6] lb build (20-40 minutos, requiere red)..."
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
