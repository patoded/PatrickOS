#!/usr/bin/env bash
# doctor.sh — diagnóstico integral de PatrickOS / Watson en un solo
# comando: repo, instalación global, scripts, workspaces y OpenClaw
# dry-run. NO ejecuta herramientas reales, NO toca red, NO escala
# privilegios POR DEFAULT (la subcomanda 'repair' sí pide sudo
# explícitamente). No 'set -e' a propósito: cada sección debe correr
# aunque otra falle, así el resumen final muestra el estado real.
#
# Uso:
#   scripts/doctor.sh                   diagnóstico
#   scripts/doctor.sh repair            diagnóstico + sudo bash scripts/install.sh + re-check
#   scripts/doctor.sh --repair          (alias)
#
# Sandbox para los smokes: $PATRICK_DOCTOR_HOME (default /tmp/patrick-doctor).
# Se borra y se recrea cada corrida; no toca $HOME/.patrick-os.

set -uo pipefail

script_dir="$(cd "$(dirname "$0")" && pwd)"
SANDBOX="${PATRICK_DOCTOR_HOME:-/tmp/patrick-doctor}"

# Parseo de subcomando. Cualquier cosa que no sea vacío / repair /
# --repair se rechaza para no confundir typos con repair silencioso.
mode="diagnose"
case "${1:-}" in
    "")             mode="diagnose" ;;
    repair|--repair) mode="repair" ;;
    *)
        echo "Uso: $0 [repair|--repair]" >&2
        exit 1
        ;;
esac

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
drift=0

ok()   { echo "[OK]   $1"; ok_count=$((ok_count + 1)); }
warn() { echo "[WARN] $1"; warn_count=$((warn_count + 1)); }
fail() { echo "[FAIL] $1"; fail_count=$((fail_count + 1)); }

show_tail() {
    # Final del output capturado, sangrado, para no inundar la pantalla.
    echo "$1" | tail -n 8 | sed 's/^/    /'
}

run_diagnostic() {
    # Reset counters en cada corrida (importante: en modo repair
    # corremos esto dos veces y queremos que el segundo resumen
    # refleje el estado POST-repair, no la suma de ambas pasadas).
    ok_count=0
    warn_count=0
    fail_count=0
    drift=0

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

    # 3) check-installed-watson.sh (FAIL si drift; WARN si no hay repo
    # o el script no existe). Marcamos drift=1 cuando falla para que
    # el caller decida si imprime el hint de reparación o si arranca
    # el flujo repair automático.
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
                drift=1
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

    # 5) watson validar (= validate-system.sh; exit = nº de FAILs).
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

    # 7) OpenClaw dry-run smoke. FAIL si no se genera el plan o si
    # plans/ no recibe la copia histórica.
    echo "--- openclaw dry-run smoke ---"
    oc_script="$script_dir/openclaw-stub.sh"
    oc_out="$(PATRICK_OS_HOME="$SANDBOX" "$oc_script" run --mode desarrollo "doctor smoke" 2>&1)"
    oc_rc=$?
    plan="$SANDBOX/workspaces/desarrollo/last-plan.md"
    plans_dir="$SANDBOX/workspaces/desarrollo/plans"
    # Conteo de *-plan.md vía glob: si no hay matches, el shopt
    # nullglob no está seteado, así que comparamos contra el patrón
    # literal cuando no hay matches reales.
    plan_count=0
    for p in "$plans_dir"/*-plan.md; do
        [ -f "$p" ] && plan_count=$((plan_count + 1))
    done
    plan_index="$plans_dir/index.tsv"
    # El índice debe existir y tener ≥1 línea (al menos la del run
    # que acabamos de hacer). 'wc -l' sobre archivo inexistente
    # rompería; el guard de -f lo evita.
    index_lines=0
    if [ -f "$plan_index" ]; then
        index_lines=$(wc -l < "$plan_index" | tr -d ' ')
    fi
    if [ "$oc_rc" -eq 0 ] && [ -f "$plan" ] && [ "$plan_count" -ge 1 ] && [ "$index_lines" -ge 1 ]; then
        ok "openclaw dry-run generó plan + historial ($plan_count) + index ($index_lines línea/s)"
    else
        plan_state="$([ -f "$plan" ] && echo present || echo missing)"
        index_state="$([ -f "$plan_index" ] && echo present || echo missing)"
        fail "openclaw dry-run (exit=$oc_rc last-plan=$plan_state historial=$plan_count index=$index_state líneas=$index_lines)"
        show_tail "$oc_out"
    fi

    # Plan viewer smoke: 'ws last-plan' y 'ws show-plan latest' tienen
    # que imprimir el plan recién generado. Verificamos contra el
    # marcador del header para no caer en falsos positivos.
    lp_out="$(PATRICK_OS_HOME="$SANDBOX" "$ws_script" last-plan desarrollo 2>&1)"
    lp_rc=$?
    sp_out="$(PATRICK_OS_HOME="$SANDBOX" "$ws_script" show-plan desarrollo latest 2>&1)"
    sp_rc=$?
    if [ "$lp_rc" -eq 0 ] && [ "$sp_rc" -eq 0 ] \
       && echo "$lp_out" | grep -q "OpenClaw Dry Run Plan" \
       && echo "$sp_out" | grep -q "OpenClaw Dry Run Plan"; then
        ok "plan viewer (last-plan + show-plan latest)"
    else
        fail "plan viewer (last-plan rc=$lp_rc, show-plan rc=$sp_rc)"
        show_tail "$lp_out"
    fi

    # Plan search smoke: 'recent' debe listar ≥1 línea con la task del
    # smoke ('doctor smoke') y 'search' debe encontrarla. Si alguno
    # falla, FAIL.
    rec_out="$(PATRICK_OS_HOME="$SANDBOX" "$ws_script" recent desarrollo 2>&1)"
    rec_rc=$?
    srch_out="$(PATRICK_OS_HOME="$SANDBOX" "$ws_script" search desarrollo "doctor smoke" 2>&1)"
    srch_rc=$?
    if [ "$rec_rc" -eq 0 ] && [ "$srch_rc" -eq 0 ] \
       && echo "$rec_out" | grep -q "doctor smoke" \
       && echo "$srch_out" | grep -q "doctor smoke"; then
        ok "plan search (recent + search)"
    else
        fail "plan search (recent rc=$rec_rc, search rc=$srch_rc)"
        show_tail "$rec_out"
        show_tail "$srch_out"
    fi
    echo

    # 8) Audit smoke. El smoke anterior debería haber escrito al
    # audit.log; si el archivo no apareció, OpenClaw no auditó bien.
    # Después corremos 'summary' para verificar que el reader funciona
    # end-to-end y mostramos las primeras líneas como evidencia.
    echo "--- audit smoke ---"
    audit_script="$script_dir/openclaw-audit.sh"
    audit_file="$SANDBOX/openclaw/audit.log"
    if [ ! -f "$audit_file" ]; then
        fail "audit.log no existe en $audit_file (OpenClaw smoke debería haberlo creado)"
    elif [ ! -x "$audit_script" ]; then
        warn "openclaw-audit.sh no presente o sin +x en $script_dir"
    else
        sum_out="$(PATRICK_OS_HOME="$SANDBOX" "$audit_script" summary 2>&1)"
        sum_rc=$?
        if [ "$sum_rc" -eq 0 ]; then
            ok "audit summary OK ($audit_file)"
            echo "$sum_out" | head -n 4 | sed 's/^/    /'
        else
            fail "audit summary falló (exit=$sum_rc)"
            show_tail "$sum_out"
        fi
    fi
    echo

    echo "Resumen: OK=$ok_count WARN=$warn_count FAIL=$fail_count"
}

# Primera corrida: diagnóstico siempre.
run_diagnostic

# Si check-installed detectó drift, dejamos siempre visible cómo
# repararlo — incluso en modo diagnose. El usuario decide si lo
# corre o no.
if [ "$drift" -eq 1 ]; then
    echo
    echo "Reparación sugerida: sudo bash scripts/install.sh"
fi

# Modo repair: validar precondiciones, correr install.sh con sudo,
# refrescar check-installed y re-diagnosticar para confirmar.
if [ "$mode" = "repair" ]; then
    if [ -z "$REPO" ]; then
        echo
        echo "Error: no se puede reparar sin repo detectado." >&2
        echo "Seteá PATRICK_OS_REPO o corré doctor desde el repo." >&2
        exit 1
    fi

    echo
    echo "=== REPAIR: sudo bash $REPO/scripts/install.sh ==="
    sudo bash "$REPO/scripts/install.sh"
    inst_rc=$?
    if [ "$inst_rc" -ne 0 ]; then
        echo
        echo "Repair: install.sh falló (exit=$inst_rc). Abortando." >&2
        exit "$inst_rc"
    fi

    echo
    echo "=== REPAIR: make check-installed ==="
    (cd "$REPO" && make check-installed) || true

    echo
    echo "=== REPAIR: re-diagnóstico ==="
    run_diagnostic
fi

exit "$fail_count"
