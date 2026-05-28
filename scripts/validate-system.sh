#!/usr/bin/env bash
# validate-system.sh — Chequeo post-boot del sistema PatrickOS.
# Reporta OK/WARN/FAIL por chequeo. No 'set -e' a propósito: nunca
# debe abortar a mitad. Exit code = nº de FAILs (0 = todo OK).

echo "PatrickOS / Watson — Validación de sistema"
echo

warn_count=0
fail_count=0

ok()   { echo "[OK]   $1"; }
warn() { echo "[WARN] $1"; warn_count=$((warn_count + 1)); }
fail() { echo "[FAIL] $1"; fail_count=$((fail_count + 1)); }

# 1) Watson en PATH.
if command -v watson >/dev/null 2>&1; then
    ok "watson en PATH: $(command -v watson)"
else
    fail "watson no está en PATH"
fi

# 2) Directorio de scripts instalado.
#    PATRICK_OS_SCRIPTS gana si está seteado (modo repo); si no, usamos
#    la ruta de instalación canónica.
scripts_dir="${PATRICK_OS_SCRIPTS:-/usr/local/share/patrick-os/scripts}"
if [ -d "$scripts_dir" ]; then
    n=$(ls -1 "$scripts_dir"/*.sh 2>/dev/null | wc -l)
    if [ "$n" -gt 0 ]; then
        ok "scripts en $scripts_dir ($n archivos .sh)"
    else
        fail "$scripts_dir existe pero no contiene .sh"
    fi
else
    warn "$scripts_dir no existe (¿modo repo? seteá PATRICK_OS_SCRIPTS)"
fi

# 3) Teclado X11 vía setxkbmap.
if command -v setxkbmap >/dev/null 2>&1; then
    layout=$(setxkbmap -query 2>/dev/null | awk '/^layout/ {print $2}')
    if [ "$layout" = "latam" ]; then
        ok "teclado X11: layout=$layout"
    elif [ -n "$layout" ]; then
        fail "teclado X11: layout=$layout (esperado: latam)"
    else
        warn "setxkbmap presente pero sin respuesta (¿sin sesión X?)"
    fi
else
    warn "setxkbmap no instalado (paquete x11-xkb-utils)"
fi

# 4) Swap con zram.
if command -v swapon >/dev/null 2>&1; then
    swap_out=$(swapon --show 2>/dev/null)
    if echo "$swap_out" | grep -q zram; then
        ok "zram activo en swap"
    elif [ -z "$swap_out" ]; then
        warn "no hay swap activa (¿zramswap.service deshabilitado?)"
    else
        warn "swap activa sin zram"
    fi
else
    warn "swapon no disponible"
fi

# 5) XFCE workspaces.
if command -v xfconf-query >/dev/null 2>&1; then
    ws=$(xfconf-query -c xfwm4 -p /general/workspace_count 2>/dev/null || true)
    if [ "$ws" = "4" ]; then
        ok "XFCE workspaces: $ws"
    elif [ -n "$ws" ]; then
        warn "XFCE workspaces: $ws (esperado: 4)"
    else
        warn "xfconf-query presente pero xfwm4 no respondió (¿sin sesión XFCE?)"
    fi
else
    warn "xfconf-query no instalado (sin XFCE en este sistema)"
fi

echo
echo "Resumen: WARN=$warn_count FAIL=$fail_count"
exit "$fail_count"
