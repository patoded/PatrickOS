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

# 0e) Pre-flight: grub-mkrescue es el generador final (paso [7/7]).
if ! command -v grub-mkrescue >/dev/null 2>&1; then
    echo "Error: grub-mkrescue no está instalado (paquetes grub-common + grub-pc-bin)."
    echo "       Instala con:  sudo apt install grub-common grub-pc-bin xorriso"
    exit 1
fi
echo "Pre-flight: grub-mkrescue presente ($(command -v grub-mkrescue))."
echo

# 1) Poblar includes.chroot con Watson + scripts + docs.
echo "[1/7] Copiando Watson, scripts y docs a includes.chroot..."

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
echo "[2/7] lb clean..."
if [ -d chroot ] || [ -d binary ] || [ -d .build ]; then
    lb clean
else
    echo "    (sin build previo, nada que limpiar)"
fi

# 3) Borrar config generada previa (puede contener 'precise' de runs anteriores).
# Solo borramos lo que produce lb_config; los archivos del usuario
# (auto/, config/package-lists/, config/hooks/, config/includes.chroot/) se quedan.
echo "[3/7] Limpiando config generada previa..."
rm -f config/binary config/bootstrap config/chroot config/common config/source
rm -rf config/archives config/binary_* config/chroot_apt config/includes config/includes.binary* config/packages config/packages.binary config/packages.chroot config/preseed config/templates
# Orphan: ubicación incorrecta de auto/config que quedó de un commit previo.
rm -rf config/auto

# 4) lb config — TODOS los parámetros explícitos, sin depender de auto/config.
# 'noauto' suprime la auto-ejecución de auto/config (que igual hace lo mismo,
# pero aquí blindamos el path).
echo "[4/7] lb config (parámetros explícitos)..."
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
    --bootappend-live "boot=casper components nomodeset" \
    --iso-application "PatrickOS Alpha" \
    --iso-publisher "Patrick Mendoza" \
    --iso-volume "PatrickOS Alpha" \
    --mirror-bootstrap http://archive.ubuntu.com/ubuntu/ \
    --mirror-chroot http://archive.ubuntu.com/ubuntu/ \
    --mirror-binary http://archive.ubuntu.com/ubuntu/

# 5) Validación: bootstrap debe declarar noble, NUNCA precise, y NUNCA
#    bootloader syslinux.
echo "[5/7] Validando config..."
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

# 6) lb build: construye el árbol binary/ (chroot + casper + grub).
# La ISO transitoria que produce internamente se descarta — el paso [7/7]
# rearma la imagen final con grub-mkrescue sobre un grub.cfg corregido.
echo "[6/7] lb build (20-40 minutos, requiere red)..."
lb build

# 7) Post-process: reescribir binary/boot/grub/grub.cfg y empacar con
# grub-mkrescue como generador final de la ISO.
#
# Motivo del bug arreglado aquí (PR #4):
#   - lb_binary_grub2 deja 'quiet splash' en la línea linux, lo que activa
#     Plymouth. En QEMU sin GPU dedicada el splash se cuelga y nunca cede
#     control a LightDM. Resultado: pantalla "Ubuntu 24.04" indefinida.
#   - Quitamos 'quiet splash' y agregamos 'nomodeset' para evitar KMS,
#     suficiente para llegar a tty/escritorio mínimo en QEMU genérico.
#   - Añadimos una entrada de terminal puro (multi-user.target) que
#     garantiza llegar a una shell aunque LightDM falle. Es la red de
#     seguridad para validar Watson durante el Alpha.
#
# IMPORTANTE — boot=casper, NO boot=live:
#   live-build es Debian-centrico y por default usa 'boot=live'. Para
#   ISOs basadas en Ubuntu el initrd lleva el hook 'casper' (no 'live'),
#   asi que el parametro correcto es 'boot=casper'. Si se deja
#   'boot=live', el initramfs no encuentra ningun script live-init,
#   ejecuta /sbin/init que no existe en el initrd, y el kernel hace:
#     Kernel panic - not syncing: Attempted to kill init!
#   Cualquier futura entrada del menu debe usar 'boot=casper'.
echo "[7/7] Reescribiendo grub.cfg y empacando con grub-mkrescue..."

GRUB_CFG="binary/boot/grub/grub.cfg"
if [ ! -f "$GRUB_CFG" ]; then
    echo "Error: $GRUB_CFG no existe — lb build no produjo el árbol esperado."
    exit 1
fi

# Detectar kernel/initrd reales (versión varía entre builds de noble).
VMLINUZ_PATH=$(ls binary/casper/vmlinuz-* 2>/dev/null | head -1 || true)
INITRD_PATH=$(ls binary/casper/initrd.img-* 2>/dev/null | head -1 || true)

if [ -z "$VMLINUZ_PATH" ] || [ -z "$INITRD_PATH" ]; then
    echo "Error: no se encontraron kernel/initrd en binary/casper/."
    ls -la binary/casper/ 2>/dev/null || true
    exit 1
fi

# Rutas relativas a la raíz del ISO (sin el prefijo 'binary').
VMLINUZ_ISO="/casper/$(basename "$VMLINUZ_PATH")"
INITRD_ISO="/casper/$(basename "$INITRD_PATH")"

echo "    Kernel: $VMLINUZ_ISO"
echo "    Initrd: $INITRD_ISO"

cat > "$GRUB_CFG" <<EOF
set default=0
set timeout=10

menuentry "PatrickOS Alpha (live)" {
    linux  $VMLINUZ_ISO boot=casper components nomodeset
    initrd $INITRD_ISO
}

menuentry "PatrickOS Alpha (live, fail-safe)" {
    linux  $VMLINUZ_ISO boot=casper components nomodeset noapic noapm nodma nomce nolapic nosmp vga=normal
    initrd $INITRD_ISO
}

menuentry "PatrickOS Alpha terminal mode" {
    linux  $VMLINUZ_ISO boot=casper components nomodeset systemd.unit=multi-user.target
    initrd $INITRD_ISO
}
EOF

echo "    grub.cfg reescrito (sin quiet/splash, con nomodeset, +terminal mode):"
sed 's/^/      /' "$GRUB_CFG"

# Descartar cualquier ISO transitoria que lb build haya dejado, para que el
# rename accidental de un build previo no esconda fallos de grub-mkrescue.
rm -f live-image-amd64.iso live-image-amd64.hybrid.iso binary.iso "$OUT_ISO"

echo "    Empacando con grub-mkrescue → $OUT_ISO"
grub-mkrescue \
    -o "$OUT_ISO" \
    -V "PatrickOS Alpha" \
    --product-name="PatrickOS Alpha" \
    --product-version="alpha" \
    binary/

if [ ! -f "$OUT_ISO" ]; then
    echo "Error: grub-mkrescue no produjo $OUT_ISO."
    exit 1
fi

echo
echo "Listo: $OUT_ISO"
ls -lh "$OUT_ISO"
