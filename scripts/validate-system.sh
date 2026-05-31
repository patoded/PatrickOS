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

# 10) home.sh presente y ejecutable (backend de 'watson inicio').
home_script="$scripts_dir/home.sh"
if [ -f "$home_script" ]; then
    if [ -x "$home_script" ]; then
        ok "home.sh presente y ejecutable: $home_script"
    else
        warn "home.sh presente pero no ejecutable: $home_script (chmod +x)"
    fi
else
    warn "home.sh ausente: $home_script (se shippea con PR #15)"
fi

# 11) Directorios base de OpenClaw Beta-0 (workspace + log). No fallamos
# si no existen: mkdir -p los crea idempotentemente. Solo WARN si el FS
# rechaza la creación (permisos, FS read-only, etc.).
os_home="${PATRICK_OS_HOME:-$HOME/.patrick-os}"
openclaw_dir="$os_home/openclaw"
workspaces_dir="$os_home/workspaces"
if mkdir -p "$openclaw_dir" 2>/dev/null; then
    ok "openclaw dir disponible: $openclaw_dir"
else
    warn "openclaw dir no se pudo crear: $openclaw_dir"
fi
if mkdir -p "$workspaces_dir" 2>/dev/null; then
    ok "workspaces dir disponible: $workspaces_dir"
else
    warn "workspaces dir no se pudo crear: $workspaces_dir"
fi

# 12) workspace.sh presente y ejecutable (backend de 'watson workspace').
workspace_script="$scripts_dir/workspace.sh"
if [ -f "$workspace_script" ]; then
    if [ -x "$workspace_script" ]; then
        ok "workspace.sh presente y ejecutable: $workspace_script"
    else
        warn "workspace.sh presente pero no ejecutable: $workspace_script (chmod +x)"
    fi
else
    warn "workspace.sh ausente: $workspace_script"
fi

# 13) doctor.sh presente y ejecutable (backend de 'watson doctor').
doctor_script="$scripts_dir/doctor.sh"
if [ -f "$doctor_script" ]; then
    if [ -x "$doctor_script" ]; then
        ok "doctor.sh presente y ejecutable: $doctor_script"
    else
        warn "doctor.sh presente pero no ejecutable: $doctor_script (chmod +x)"
    fi
else
    warn "doctor.sh ausente: $doctor_script"
fi

# 14) openclaw-policy.sh presente y ejecutable (gate de OpenClaw).
policy_script="$scripts_dir/openclaw-policy.sh"
if [ -f "$policy_script" ]; then
    if [ -x "$policy_script" ]; then
        ok "openclaw-policy.sh presente y ejecutable: $policy_script"
    else
        warn "openclaw-policy.sh presente pero no ejecutable: $policy_script (chmod +x)"
    fi
else
    warn "openclaw-policy.sh ausente: $policy_script"
fi

# 15) configs/openclaw-policy.yaml presente. Como con scripts_dir,
# probamos primero $PATRICK_OS_CONFIGS, después /usr/local/share/... y
# después ../configs respecto a scripts_dir (modo repo).
configs_dir="${PATRICK_OS_CONFIGS:-}"
if [ -z "$configs_dir" ]; then
    if [ -d "/usr/local/share/patrick-os/configs" ]; then
        configs_dir="/usr/local/share/patrick-os/configs"
    elif [ -d "$(dirname "$scripts_dir")/configs" ]; then
        configs_dir="$(dirname "$scripts_dir")/configs"
    fi
fi
policy_yaml="$configs_dir/openclaw-policy.yaml"
if [ -n "$configs_dir" ] && [ -f "$policy_yaml" ]; then
    ok "openclaw policy yaml presente: $policy_yaml"
else
    warn "openclaw policy yaml ausente (configs_dir='${configs_dir:-?}')"
fi

# 16) Kill switch local. La presencia del archivo NO es un error: es
# una pausa intencional del usuario. Lo reportamos como WARN para
# que se vea cada vez que corre 'watson validar'.
kill_switch_file="${PATRICK_OS_HOME:-$HOME/.patrick-os}/openclaw/KILL_SWITCH"
if [ -f "$kill_switch_file" ]; then
    warn "OpenClaw KILL_SWITCH activo: $kill_switch_file (claw run está bloqueado)"
else
    ok "OpenClaw KILL_SWITCH inactivo"
fi

# 17) openclaw-audit.sh presente y ejecutable (lectura del audit log).
audit_script="$scripts_dir/openclaw-audit.sh"
if [ -f "$audit_script" ]; then
    if [ -x "$audit_script" ]; then
        ok "openclaw-audit.sh presente y ejecutable: $audit_script"
    else
        warn "openclaw-audit.sh presente pero no ejecutable: $audit_script (chmod +x)"
    fi
else
    warn "openclaw-audit.sh ausente: $audit_script"
fi

# 18) openclaw-tools.sh presente y ejecutable (viewer del tool registry).
tools_script="$scripts_dir/openclaw-tools.sh"
if [ -f "$tools_script" ]; then
    if [ -x "$tools_script" ]; then
        ok "openclaw-tools.sh presente y ejecutable: $tools_script"
    else
        warn "openclaw-tools.sh presente pero no ejecutable: $tools_script (chmod +x)"
    fi
else
    warn "openclaw-tools.sh ausente: $tools_script"
fi

# 19) openclaw-contracts.sh presente y ejecutable (validador de contratos).
contracts_script="$scripts_dir/openclaw-contracts.sh"
if [ -f "$contracts_script" ]; then
    if [ -x "$contracts_script" ]; then
        ok "openclaw-contracts.sh presente y ejecutable: $contracts_script"
    else
        warn "openclaw-contracts.sh presente pero no ejecutable: $contracts_script (chmod +x)"
    fi
else
    warn "openclaw-contracts.sh ausente: $contracts_script"
fi

# 20) openclaw-negative-tests.sh presente y ejecutable (suite de pruebas negativas).
negtest_script="$scripts_dir/openclaw-negative-tests.sh"
if [ -f "$negtest_script" ]; then
    if [ -x "$negtest_script" ]; then
        ok "openclaw-negative-tests.sh presente y ejecutable: $negtest_script"
    else
        warn "openclaw-negative-tests.sh presente pero no ejecutable: $negtest_script (chmod +x)"
    fi
else
    warn "openclaw-negative-tests.sh ausente: $negtest_script"
fi

# 21) openclaw-simulate-tool.sh presente y ejecutable (simulación
# audit-only de tools del registry).
sim_script="$scripts_dir/openclaw-simulate-tool.sh"
if [ -f "$sim_script" ]; then
    if [ -x "$sim_script" ]; then
        ok "openclaw-simulate-tool.sh presente y ejecutable: $sim_script"
    else
        warn "openclaw-simulate-tool.sh presente pero no ejecutable: $sim_script (chmod +x)"
    fi
else
    warn "openclaw-simulate-tool.sh ausente: $sim_script"
fi

# 22) openclaw-readiness.sh presente y ejecutable (gate de Beta-1 readiness).
rd_script="$scripts_dir/openclaw-readiness.sh"
if [ -f "$rd_script" ]; then
    if [ -x "$rd_script" ]; then
        ok "openclaw-readiness.sh presente y ejecutable: $rd_script"
    else
        warn "openclaw-readiness.sh presente pero no ejecutable: $rd_script (chmod +x)"
    fi
else
    warn "openclaw-readiness.sh ausente: $rd_script"
fi

# 23) openclaw-report.sh presente y ejecutable (reporte consolidado).
rp_script="$scripts_dir/openclaw-report.sh"
if [ -f "$rp_script" ]; then
    if [ -x "$rp_script" ]; then
        ok "openclaw-report.sh presente y ejecutable: $rp_script"
    else
        warn "openclaw-report.sh presente pero no ejecutable: $rp_script (chmod +x)"
    fi
else
    warn "openclaw-report.sh ausente: $rp_script"
fi

echo
echo "Resumen: WARN=$warn_count FAIL=$fail_count"
exit "$fail_count"
