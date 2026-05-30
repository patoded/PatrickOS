#!/usr/bin/env bash
# doctor.sh — diagnóstico integral de PatrickOS / Watson en un solo
# comando: repo, instalación global, scripts, workspaces y OpenClaw
# dry-run. NO ejecuta herramientas reales, NO toca red, NO escala
# privilegios. No 'set -e' a propósito: cada sección debe correr
# aunque otra falle, así el resumen final muestra el estado real.
#
# Uso:
#   scripts/doctor.sh           (también: watson doctor / watson doc / make doctor)
#
# Sandbox para los smokes: $PATRICK_DOCTOR_HOME (default /tmp/patrick-doctor).
# Se borra y se recrea cada corrida; no toca $HOME/.patrick-os.

set -uo pipefail

script_dir="$(cd "$(dirname "$0")" && pwd)"
SANDBOX="${PATRICK_DOCTOR_HOME:-/tmp/patrick-doctor}"

# Detección del repo fuente. doctor.sh puede correr desde:
#   - el repo en sí (script_dir/.. tiene .git, watson/watson.py, Makefile),
#   - una instalación global (script_dir = /usr/local/share/patrick-os/scripts,
#     que NO es el repo: no hay .git, no hay Makefile).
# En el segundo caso, git status / make check / check-installed solo
# tienen sentido contra el repo fuente. Buscamos en este orden:
#   1) $PATRICK_OS_REPO (override explícito; basta con que tenga watson/watson.py).
#   2) $PWD si parece repo (watson/watson.py + .git).
#   3) ~/patrick-os si parece repo.
# Si nada matchea, REPO queda vacío y las secciones que lo necesitan
# se marcan WARN — el resto del doctor sigue corriendo.
is_repo() {
    [ -n "${1:-}" ] && [ -f "$1/watson/watson.py" ] && [ -d "$1/.git" ]
}

REPO=""
if [ -n "${PATRICK_OS_REPO:-}" ] && [ -f "$PATRICK_OS_REPO/watson/watson.py" ]; then
    REPO="$(cd "$PATRICK_OS_REPO" && pwd)"
elif is_repo "$PWD"; then
    REPO="$PWD"
elif is_repo "$HOME/patrick-os"; then
    REPO="$HOME/patrick-os"
fi

ok_count=0
warn_count=0
fail_count=0

ok()   { echo "[OK]   $1"; ok_count=$((ok_count + 1)); }
warn() { echo "[WARN] $1"; warn_count=$((warn_count + 1)); }
fail() { echo "[FAIL] $1"; fail_count=$((fail_count + 1)); }

show_tail() {
    # Final del output capturado, sangrado, para no inundar la pantalla.
    echo "$1" | tail -n 8 | sed 's/^/    /'
}

echo "PatrickOS Doctor"
echo "Repo:    ${REPO:-(no detectado)}"
echo "Sandbox: $SANDBOX"
echo

# 1) git status (WARN si hay cambios; WARN si no hay repo detectado).
echo "--- git status ---"
if [ -z "$REPO" ]; then
    warn "git status omitido (repo no detectado; seteá PATRICK_OS_REPO o corré desde el repo)"
else
    git_out="$(cd "$REPO" && git status --short 2>&1)"
    if [ -z "$git_out" ]; then
        ok "repo limpio"
    else
        warn "repo con cambios sin commitear"
        echo "$git_out" | sed 's/^/    /'
    fi
fi
echo

# 2) make check (FAIL si exit ≠ 0; WARN si no hay repo).
echo "--- make check ---"
if [ -z "$REPO" ]; then
    warn "make check omitido (repo no detectado)"
else
    mk_out="$(cd "$REPO" && make check 2>&1)"
    mk_rc=$?
    if [ "$mk_rc" -eq 0 ]; then
        ok "make check (fails=0)"
    else
        fail "make check (exit=$mk_rc)"
        show_tail "$mk_out"
    fi
fi
echo

# 3) check-installed-watson.sh (FAIL si drift; WARN si no hay repo o
# el script no existe). Usamos la copia del REPO, no la de script_dir:
# si doctor corre instalado, el script_dir/check-installed-watson.sh
# computaría repo_dir = /usr/local/share/patrick-os y compararía consigo
# mismo (sin sentido). El script del repo siempre conoce su propio repo.
echo "--- check-installed ---"
if [ -z "$REPO" ]; then
    warn "check-installed omitido (repo no detectado)"
else
    ci="$REPO/scripts/check-installed-watson.sh"
    if [ ! -x "$ci" ]; then
        warn "check-installed-watson.sh no presente o sin +x en $REPO"
    else
        ci_out="$("$ci" 2>&1)"
        ci_rc=$?
        if [ "$ci_rc" -eq 0 ]; then
            ok "check-installed (instalación global en sync)"
        else
            fail "check-installed (drift respecto al repo)"
            show_tail "$ci_out"
        fi
    fi
fi
echo

# 4) watson version (WARN si no hay watson global).
echo "--- watson version ---"
if command -v watson >/dev/null 2>&1; then
    wv_out="$(watson version 2>&1)"
    if [ -n "$wv_out" ]; then
        ok "watson version"
        echo "$wv_out" | sed 's/^/    /'
    else
        warn "watson version no produjo output"
    fi
else
    warn "watson no está en PATH"
fi
echo

# 5) watson validar (= validate-system.sh; exit = nº de FAILs). WARN si
# no hay watson global; FAIL si exit != 0.
echo "--- watson validar ---"
if command -v watson >/dev/null 2>&1; then
    val_out="$(watson validar 2>&1)"
    val_rc=$?
    if [ "$val_rc" -eq 0 ]; then
        ok "watson validar (FAIL=0)"
    else
        fail "watson validar (exit=$val_rc)"
        show_tail "$val_out"
    fi
else
    warn "watson no está en PATH (skip validar)"
fi
echo

# 6) Workspace smoke en sandbox aislado.
echo "--- workspace smoke ---"
rm -rf "$SANDBOX"
ws_script="$script_dir/workspace.sh"
ws_init_out="$(PATRICK_OS_HOME="$SANDBOX" "$ws_script" init desarrollo 2>&1)"
ws_init_rc=$?
ws_path_out="$(PATRICK_OS_HOME="$SANDBOX" "$ws_script" path desarrollo 2>&1)"
ws_path_rc=$?
if [ "$ws_init_rc" -eq 0 ] && [ "$ws_path_rc" -eq 0 ] && [ -d "$ws_path_out" ]; then
    ok "workspace init/path (desarrollo en $ws_path_out)"
else
    fail "workspace smoke (init_rc=$ws_init_rc path_rc=$ws_path_rc)"
    show_tail "$ws_init_out"
    show_tail "$ws_path_out"
fi
echo

# 7) OpenClaw dry-run smoke. FAIL si no se genera el plan.
echo "--- openclaw dry-run smoke ---"
oc_script="$script_dir/openclaw-stub.sh"
oc_out="$(PATRICK_OS_HOME="$SANDBOX" "$oc_script" run --mode desarrollo "doctor smoke" 2>&1)"
oc_rc=$?
plan="$SANDBOX/workspaces/desarrollo/last-plan.md"
if [ "$oc_rc" -eq 0 ] && [ -f "$plan" ]; then
    ok "openclaw dry-run generó plan: $plan"
else
    plan_state="$([ -f "$plan" ] && echo present || echo missing)"
    fail "openclaw dry-run (exit=$oc_rc plan=$plan_state)"
    show_tail "$oc_out"
fi
echo

echo "Resumen: OK=$ok_count WARN=$warn_count FAIL=$fail_count"
exit "$fail_count"
