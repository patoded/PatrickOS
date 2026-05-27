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

# 0d) Informativo: isohybrid solo aplica a --binary-images iso-hybrid (USB
# bootable). Para Alpha usamos --binary-images iso (CD-ROM booteable simple
# en QEMU/VBox), así que isohybrid NO es requisito. Reportamos su presencia
# como dato y seguimos.
if command -v isohybrid >/dev/null 2>&1; then
    echo "Pre-flight: isohybrid presente ($(command -v isohybrid)) — no requerido con --binary-images iso."
else
    echo "Pre-flight: isohybrid ausente — no requerido con --binary-images iso."
fi
echo

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
# --bootloader en live-build 3.x acepta grub|grub2|syslinux|yaboot:
#   - syslinux: dispara lb_binary_syslinux → instala
#     syslinux-themes-ubuntu-oneiric (muerto en noble) y gfxboot-theme-ubuntu
#     (sin candidato en noble).
#   - grub: dispara lb_binary_grub → intenta instalar grub-legacy
#     (paquete muerto en noble).
#   - grub2: dispara lb_binary_grub2 → instala grub-pc (GRUB 2 para BIOS,
#     vigente en noble). Es el único valor compatible.
# Verificación en fuente: /usr/lib/live/build/lb_binary_grub2 línea 27 hace
# 'exit 0' si LB_BOOTLOADER != grub2; línea 54 referencia grub-pc.
#
# --binary-images: usamos 'iso' (CD-ROM booteable simple). 'iso-hybrid' añade
# una firma isolinux.bin con isohybrid post-build, pero isohybrid no reconoce
# imágenes booteadas con GRUB2 ("boot loader does not have an isolinux.bin
# hybrid signature"). Para Alpha QEMU/VBox no necesitamos USB-hybrid.
lb config noauto \
    --mode ubuntu \
    --distribution noble \
    --archive-areas "main universe multiverse restricted" \
    --linux-flavours generic \
    --binary-images iso \
    --bootloader grub2 \
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

# 5) Validación: bootstrap debe declarar noble, NUNCA precise, y NUNCA
#    bootloader syslinux.
echo "[5/6] Validando config..."
echo
echo "--- config (líneas clave) ---"
grep -E '^LB_(MODE|DISTRIBUTION|PARENT_DISTRIBUTION|ARCHIVE_AREAS|MIRROR_|BOOTLOADER|BINARY_IMAGES)=' \
    config/binary config/bootstrap config/common 2>/dev/null || true
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

if ! grep -q '^LB_BOOTLOADER="grub2"$' config/binary 2>/dev/null; then
    echo "ERROR: LB_BOOTLOADER no es 'grub2'. Esperado: grub2 (GRUB 2 vía grub-pc)."
    echo "       'grub' = grub-legacy (paquete muerto en noble)."
    echo "       'syslinux' = pide gfxboot-theme-ubuntu (paquete muerto)."
    grep '^LB_BOOTLOADER=' config/binary
    echo "Abortando antes de lb build."
    exit 1
fi

if ! grep -q '^LB_BINARY_IMAGES="iso"$' config/binary 2>/dev/null; then
    echo "ERROR: LB_BINARY_IMAGES no es 'iso'. Esperado: iso (CD-ROM simple)."
    echo "       'iso-hybrid' obliga a isohybrid sobre la ISO GRUB2 → falla con"
    echo "       'boot loader does not have an isolinux.bin hybrid signature'."
    grep '^LB_BINARY_IMAGES=' config/binary
    echo "Abortando antes de lb build."
    exit 1
fi

echo "    OK: noble + grub2 + iso confirmados (sin precise/syslinux/grub-legacy/hybrid)."

# 6) lb build: construye la ISO.
echo "[6/6] lb build (20-40 minutos, requiere red)..."
lb build

# Renombrar al nombre del proyecto. live-build varía el nombre del output
# según --binary-images:
#   iso         → live-image-amd64.iso
#   iso-hybrid  → live-image-amd64.hybrid.iso
# Algunas versiones producen binary.iso. Aceptamos cualquiera de los nombres
# conocidos; como último recurso, cualquier *.iso en el dir que no sea el
# output final.
GENERATED=""
for candidate in live-image-amd64.iso live-image-amd64.hybrid.iso binary.iso; do
    if [ -f "$candidate" ]; then
        GENERATED="$candidate"
        break
    fi
done
if [ -z "$GENERATED" ]; then
    GENERATED=$(ls -1 *.iso 2>/dev/null | grep -v '^patrick-os-alpha\.iso$' | head -1)
fi

if [ -n "$GENERATED" ] && [ -f "$GENERATED" ]; then
    mv "$GENERATED" "$OUT_ISO"
    echo
    echo "Listo: $OUT_ISO  (origen: $GENERATED)"
    ls -lh "$OUT_ISO"
else
    echo "Error: no se generó ningún archivo .iso en $script_dir."
    echo "Revisa los logs en $script_dir/binary.log y $script_dir/chroot.log"
    ls -la "$script_dir"/*.iso 2>/dev/null || echo "  (sin .iso visibles)"
    exit 1
fi
