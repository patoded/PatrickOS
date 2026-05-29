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

# 6) OpenClaw stub presente y ejecutable. Es solo el stub no-op de PR #10;
# no implica que haya runtime real instalado.
openclaw_stub="$scripts_dir/openclaw-stub.sh"
if [ -f "$openclaw_stub" ]; then
    if [ -x "$openclaw_stub" ]; then
        ok "openclaw stub presente y ejecutable: $openclaw_stub"
    else
        warn "openclaw stub presente pero no ejecutable: $openclaw_stub (chmod +x)"
    fi
else
    warn "openclaw stub ausente: $openclaw_stub (se shippea con PR #10)"
fi

# 7) notes.sh presente y ejecutable (backend de 'watson nota' / 'notas').
notes_script="$scripts_dir/notes.sh"
if [ -f "$notes_script" ]; then
    if [ -x "$notes_script" ]; then
        ok "notes.sh presente y ejecutable: $notes_script"
    else
        warn "notes.sh presente pero no ejecutable: $notes_script (chmod +x)"
    fi
else
    warn "notes.sh ausente: $notes_script (se shippea con PR #12)"
fi

# 8) todos.sh presente y ejecutable (backend de 'watson tarea' / 'tareas').
todos_script="$scripts_dir/todos.sh"
if [ -f "$todos_script" ]; then
    if [ -x "$todos_script" ]; then
        ok "todos.sh presente y ejecutable: $todos_script"
    else
        warn "todos.sh presente pero no ejecutable: $todos_script (chmod +x)"
    fi
else
    warn "todos.sh ausente: $todos_script (se shippea con PR #13)"
fi

# 9) daily.sh presente y ejecutable (backend de 'watson diario').
daily_script="$scripts_dir/daily.sh"
if [ -f "$daily_script" ]; then
    if [ -x "$daily_script" ]; then
        ok "daily.sh presente y ejecutable: $daily_script"
    else
        warn "daily.sh presente pero no ejecutable: $daily_script (chmod +x)"
    fi
else
    warn "daily.sh ausente: $daily_script (se shippea con PR #14)"
fi

echo
echo "Resumen: WARN=$warn_count FAIL=$fail_count"
exit "$fail_count"
