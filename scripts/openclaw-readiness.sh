#!/usr/bin/env bash
# openclaw-readiness.sh — gate explícito que evalúa si OpenClaw
# puede avanzar hacia Beta-1. Por diseño concluye:
#   ready_for_simulated_beta1=yes    (todos los OK pasan)
#   ready_for_real_execution=no      (runtime real no implementado)
#
# NO ejecuta herramientas reales: cada check delega a un script ya
# auditado del repo (policy, contracts, tools, negative-tests,
# doctor, openclaw-stub con sandbox tmp).
#
# Uso:
#   openclaw-readiness.sh             (default: beta1 check)
#   openclaw-readiness.sh beta1       (explícito)
#   openclaw-readiness.sh --verbose   (muestra output capturado)
#
# Exit code:
#   0 si ready_for_simulated_beta1=yes (BLOCKED en real execution
#     NO cuenta — es estado por diseño).
#   1 si cualquier check requerido falla.
#
# Doctor smoke usa PATRICK_DOCTOR_SKIP_READINESS=1 para evitar
# recursión. Inversamente, readiness setea ese mismo env cuando
# llama doctor.

set -uo pipefail

script_dir="$(cd "$(dirname "$0")" && pwd)"

# Detectar si entramos desde una cadena (report/doctor/negative-
# tests nos llama). En ese caso saltamos sub-checks que llamarían
# de vuelta hacia esos scripts y entrarían en loop.
CHAIN_SKIP_NT=0
CHAIN_SKIP_DOCTOR=0
if [ -n "${PATRICK_DOCTOR_SKIP_NEGATIVE_TESTS:-}" ]; then
    CHAIN_SKIP_NT=1
fi
if [ -n "${PATRICK_DOCTOR_SKIP_READINESS:-}" ]; then
    CHAIN_SKIP_DOCTOR=1
fi

VERBOSE=0
for arg in "$@"; do
    case "$arg" in
        --verbose|-v) VERBOSE=1 ;;
        beta1|readiness) : ;;  # modos default, no-op
        *) ;;  # ignoramos para futuras extensiones
    esac
done

fails=0
ok()         { echo "[OK] $1"; }
fail_msg()   { echo "[FAIL] $1"; fails=$((fails + 1)); }
blocked()    { echo "[BLOCKED] $1"; }
vlog()       { [ "$VERBOSE" = 1 ] && echo "$1" | sed 's/^/    /'; return 0; }

check_silent() {
    # check_silent <label> <cmd...> — espera exit 0; OK/FAIL en función.
    local label="$1"; shift
    local out rc
    out="$("$@" 2>&1)"
    rc=$?
    vlog "[$label] rc=$rc"
    vlog "$out"
    if [ "$rc" -eq 0 ]; then
        ok "$label"
    else
        fail_msg "$label (exit=$rc)"
        [ "$VERBOSE" -ne 1 ] && echo "$out" | tail -n 4 | sed 's/^/      /'
    fi
}

echo "OpenClaw Beta-1 Readiness"
echo

# 1) policy check OK.
check_silent "policy" "$script_dir/openclaw-policy.sh" check

# 2) contracts check OK (12 campos + reglas duras).
check_silent "contracts" "$script_dir/openclaw-contracts.sh" check

# 3) tools registry tiene candidatas pero todas disabled.
tools_out="$("$script_dir/openclaw-tools.sh" list 2>&1)"
tools_rc=$?
if [ "$tools_rc" -eq 0 ] && echo "$tools_out" | grep -q "No hay herramientas habilitadas."; then
    n_cand="$(echo "$tools_out" | grep -cE ' (disabled|enabled)$' || true)"
    if [ "$n_cand" -gt 0 ]; then
        ok "tools registry disabled ($n_cand candidata(s))"
    else
        ok "tools registry disabled (vacío)"
    fi
else
    fail_msg "tools registry (rc=$tools_rc)"
    vlog "$tools_out"
fi

# 4) negative tests OK (suite completa). Si readiness fue llamado
# desde negative-tests vía report (cadena nt → report → readiness),
# saltamos para no entrar en loop. El caller ya está corriendo la
# suite — no necesitamos correrla otra vez.
if [ "$CHAIN_SKIP_NT" = "1" ]; then
    ok "negative tests (omitido para evitar recursión)"
else
    # Inline export: el flag llega al hijo (negative-tests) pero no
    # se queda en nuestro env. Le seteamos los 3 SKIP_* al hijo
    # para que cualquier doctor que dispare a su vez salte sus
    # smokes recursivos.
    PATRICK_DOCTOR_SKIP_NEGATIVE_TESTS=1 \
    PATRICK_DOCTOR_SKIP_READINESS=1 \
    PATRICK_DOCTOR_SKIP_REPORT=1 \
        check_silent "negative tests" "$script_dir/openclaw-negative-tests.sh"
fi

# 5) doctor OK. Si readiness fue llamado desde una cadena que
# pasa por doctor (CHAIN_SKIP_DOCTOR), saltamos para no entrar en
# loop. Si no, llamamos doctor con los 3 SKIP_* inline para que
# salte sus smokes recursivos (readiness/negative-tests/report).
if [ "$CHAIN_SKIP_DOCTOR" = "1" ]; then
    ok "doctor (omitido para evitar recursión)"
else
    PATRICK_DOCTOR_SKIP_NEGATIVE_TESTS=1 \
    PATRICK_DOCTOR_SKIP_READINESS=1 \
    PATRICK_DOCTOR_SKIP_REPORT=1 \
        check_silent "doctor" "$script_dir/doctor.sh"
fi

# 6, 7, 8) Verificación de gates end-to-end en sandbox tmp.
# Un solo sandbox para los tres checks: execute gate blocked-by-design,
# simulated execution binding, y la confirmación implícita de que
# el flujo completo no ejecuta nada real.
sandbox_eg="$(mktemp -d)"
PATRICK_OS_HOME="$sandbox_eg" "$script_dir/openclaw-stub.sh" run \
    --mode desarrollo --tag readiness --priority normal \
    "execution gate readiness check" > /dev/null 2>&1
plan_bn=""
for p in "$sandbox_eg/workspaces/desarrollo/plans/"*-plan.md; do
    [ -f "$p" ] && plan_bn="$(basename "$p")"
done

if [ -z "$plan_bn" ]; then
    fail_msg "execution gate (no se pudo generar plan en sandbox)"
    fail_msg "simulated binding (sin plan)"
else
    PATRICK_OS_HOME="$sandbox_eg" "$script_dir/workspace.sh" approve-plan \
        desarrollo "$plan_bn" > /dev/null 2>&1
    # 6) execute aprobado → blocked-by-design + exit != 0.
    eg_out="$(PATRICK_OS_HOME="$sandbox_eg" "$script_dir/openclaw-stub.sh" execute \
        --mode desarrollo "$plan_bn" 2>&1)"
    eg_rc=$?
    if [ "$eg_rc" -ne 0 ] && echo "$eg_out" | grep -q "blocked-by-design"; then
        ok "execution gate blocked-by-design"
    else
        fail_msg "execution gate (esperado blocked-by-design, rc=$eg_rc)"
        vlog "$eg_out"
    fi
    # 7) simulated execution binding → simulated-only + exit 0.
    se_out="$(PATRICK_OS_HOME="$sandbox_eg" "$script_dir/openclaw-stub.sh" simulate-execute \
        --mode desarrollo --tool read_file "$plan_bn" 2>&1)"
    se_rc=$?
    if [ "$se_rc" -eq 0 ] && echo "$se_out" | grep -q "Status: simulated-only"; then
        ok "simulated binding"
    else
        fail_msg "simulated binding (rc=$se_rc, esperado simulated-only)"
        vlog "$se_out"
    fi
    # 7b) simulated execution manifest: el simulate-execute anterior
    # debió crear <workspace>/executions/<ts>-<tool>-manifest.md.
    mf_count=0
    for mf in "$sandbox_eg/workspaces/desarrollo/executions/"*-manifest.md; do
        [ -f "$mf" ] && mf_count=$((mf_count + 1))
    done
    if [ "$mf_count" -ge 1 ]; then
        ok "simulated execution manifest ($mf_count manifest/s)"
    else
        fail_msg "simulated execution manifest (no se generó manifest)"
    fi
    # 7c) execution manifest index: el simulate-execute también
    # debió appendear a executions/index.tsv. El recent-executions
    # debe mostrar al menos la tool que ejecutamos (read_file).
    idx_file="$sandbox_eg/workspaces/desarrollo/executions/index.tsv"
    idx_lines=0
    [ -f "$idx_file" ] && idx_lines=$(wc -l < "$idx_file" | tr -d ' ')
    rec_out="$(PATRICK_OS_HOME="$sandbox_eg" "$script_dir/workspace.sh" recent-executions desarrollo 2>&1)"
    rec_rc=$?
    if [ "$idx_lines" -ge 1 ] && [ "$rec_rc" -eq 0 ] && echo "$rec_out" | grep -q "read_file"; then
        ok "execution manifest index ($idx_lines línea/s)"
    else
        fail_msg "execution manifest index (lines=$idx_lines rec_rc=$rec_rc)"
        vlog "$rec_out"
    fi
fi
rm -rf "$sandbox_eg"

# 8) Runtime real (NO debería existir) — BLOCKED por diseño, no
# cuenta como FAIL. Es el estado terminal que esperamos en Beta-0.
blocked "real execution runtime not implemented"

# Resumen.
echo
echo "Resumen:"
if [ "$fails" -gt 0 ]; then
    echo "ready_for_simulated_beta1=no"
    echo "ready_for_real_execution=no"
    echo
    echo "FAILED ($fails check/s)." >&2
    exit 1
fi
echo "ready_for_simulated_beta1=yes"
echo "ready_for_real_execution=no"
exit 0
