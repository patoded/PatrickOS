#!/usr/bin/env bash
# openclaw-negative-tests.sh — suite de pruebas negativas para
# OpenClaw Beta-0. Asume escenarios maliciosos / mal-formados y
# verifica que cada control respectivo bloquea con su exit code y
# evento de audit. NO ejecuta herramientas reales; cada test usa
# los gates ya en código (ver docs/OPENCLAW_NEGATIVE_TESTS.md).
#
# Uso:
#   openclaw-negative-tests.sh             corre la suite
#   openclaw-negative-tests.sh --verbose   imprime el output capturado
#
# Sandbox dedicado: $PATRICK_OS_HOME si fue seteado externamente, si
# no /tmp/patrick-negative-tests. Se borra y recrea al inicio. NUNCA
# fallback a $HOME/.patrick-os (no queremos tocar el estado real del
# usuario).
#
# Exit code = nº de FAILs.

set -uo pipefail

VERBOSE=0
case "${1:-}" in
    --verbose|-v) VERBOSE=1 ;;
esac

script_dir="$(cd "$(dirname "$0")" && pwd)"

# No exportamos guards a nivel global porque tests internos del
# runner (16, 18) llaman a openclaw-stub.sh y sus chains; tener
# SKIP_* exportado globalmente hace que readiness/doctor/report
# se contaminen para sí mismos. Cuando los tests 27/28 lleguen a
# llamar 'report', el report verá las flags vía su propio detect
# (REPORT_FROM_CHAIN) o las herede inline.

# Para que report (test 27/28) NO entre en loop, sí necesitamos
# avisarle. Lo hacemos pasando los flags inline en el call de los
# tests 27/28 más abajo.

# Sandbox dedicado.
if [ -n "${PATRICK_OS_HOME:-}" ]; then
    SANDBOX="$PATRICK_OS_HOME"
else
    SANDBOX="/tmp/patrick-negative-tests"
fi
export PATRICK_OS_HOME="$SANDBOX"
rm -rf "$SANDBOX"
mkdir -p "$SANDBOX"

ok_count=0
fail_count=0

ok()       { echo "[OK]   $1"; ok_count=$((ok_count + 1)); }
fail_msg() { echo "[FAIL] $1"; fail_count=$((fail_count + 1)); }
vlog()     { [ "$VERBOSE" = 1 ] && echo "$1" | sed 's/^/      /'; return 0; }

# Ejecuta un comando ESPERANDO que falle (exit != 0). Si falla → OK.
# Si pasa → FAIL del test (significa que el gate NO bloqueó).
run_fail() {
    local label="$1"; shift
    local out rc
    out="$("$@" 2>&1)"
    rc=$?
    vlog "rc=$rc"
    vlog "$out"
    if [ "$rc" -ne 0 ]; then
        ok "$label (exit=$rc, bloqueado como esperado)"
    else
        fail_msg "$label (exit=0 — esperado bloqueo)"
        echo "$out" | tail -n 4 | sed 's/^/        /'
    fi
}

# Ejecuta un comando ESPERANDO que pase (exit 0).
run_pass() {
    local label="$1"; shift
    local out rc
    out="$("$@" 2>&1)"
    rc=$?
    vlog "rc=$rc"
    vlog "$out"
    if [ "$rc" -eq 0 ]; then
        ok "$label (exit=0)"
    else
        fail_msg "$label (exit=$rc — esperado OK)"
        echo "$out" | tail -n 4 | sed 's/^/        /'
    fi
}

OC="$script_dir/openclaw-stub.sh"
WS="$script_dir/workspace.sh"
PL="$script_dir/openclaw-policy.sh"
TL="$script_dir/openclaw-tools.sh"

echo "PatrickOS OpenClaw Negative Tests"
echo "Sandbox: $SANDBOX"
echo

# ---------------------------------------------------------------
# 1) Policy tampered → claw run blocked
# ---------------------------------------------------------------
# Copiamos la policy local con 'network: enabled' a un tmp y
# apuntamos PATRICK_OS_POLICY a la versión rota. policy check debe
# fallar → claw run aborta sin escribir nada.
TAMPER_POL=$(mktemp)
SOURCE_POL="$("$PL" path 2>/dev/null || true)"
if [ -n "$SOURCE_POL" ] && [ -f "$SOURCE_POL" ]; then
    sed 's/^network:.*/network: enabled/' "$SOURCE_POL" > "$TAMPER_POL"
else
    # Sin policy fuente: escribimos una policy mínima con network roto
    # para reproducir el escenario.
    cat > "$TAMPER_POL" <<'EOF'
version: 1
default_mode: dry_run
network: enabled
sudo: disabled
plugins: disabled
marketplace: disabled
tool_whitelist: []
kill_switch: true
EOF
fi
PATRICK_OS_POLICY="$TAMPER_POL" run_fail \
    "1. policy tampered (network: enabled) → claw run blocked" \
    "$OC" run --mode desarrollo "policy tampered test"
rm -f "$TAMPER_POL"

# ---------------------------------------------------------------
# 2) Kill switch activo → claw run blocked
# ---------------------------------------------------------------
"$OC" kill "negative-tests" > /dev/null 2>&1
run_fail "2. kill switch activo → claw run blocked" \
    "$OC" run --mode desarrollo "kill switch test"
"$OC" unkill > /dev/null 2>&1

# ---------------------------------------------------------------
# 3) execute sin aprobación → missing approval
# ---------------------------------------------------------------
# Generamos un plan limpio primero (el run debe pasar).
"$OC" run --mode desarrollo --tag negtest --priority normal "plan para test 3 y 4" > /dev/null 2>&1
PLAN_BASENAME=""
for p in "$SANDBOX/workspaces/desarrollo/plans/"*-plan.md; do
    [ -f "$p" ] && PLAN_BASENAME="$(basename "$p")"
done
if [ -z "$PLAN_BASENAME" ]; then
    fail_msg "3. (precondición rota) no pude generar plan para los tests 3-4"
else
    run_fail "3. execute sin aprobación → missing approval" \
        "$OC" execute --mode desarrollo "$PLAN_BASENAME"
fi

# ---------------------------------------------------------------
# 4) execute con aprobación → blocked-by-design (Beta-0 = exit 1)
# ---------------------------------------------------------------
if [ -n "$PLAN_BASENAME" ]; then
    "$WS" approve-plan desarrollo "$PLAN_BASENAME" > /dev/null 2>&1
    run_fail "4. execute aprobado → blocked-by-design (exit 1)" \
        "$OC" execute --mode desarrollo "$PLAN_BASENAME"
else
    fail_msg "4. (precondición rota) sin PLAN_BASENAME no puedo testear approve+execute"
fi

# ---------------------------------------------------------------
# 5) path traversal en show-plan
# ---------------------------------------------------------------
run_fail "5. ws show-plan desarrollo '../secreto' → rechazado" \
    "$WS" show-plan desarrollo "../secreto"

# ---------------------------------------------------------------
# 6) tag inválido
# ---------------------------------------------------------------
run_fail "6. claw run --tag '../../bad' → rechazado" \
    "$OC" run --mode desarrollo --tag "../../bad" "x"

# ---------------------------------------------------------------
# 7) priority inválida
# ---------------------------------------------------------------
run_fail "7. claw run --priority urgent → rechazado" \
    "$OC" run --mode desarrollo --priority urgent "x"

# ---------------------------------------------------------------
# 8) tools registry vacío (Beta-0)
# ---------------------------------------------------------------
out8="$("$TL" list 2>&1)"
if echo "$out8" | grep -q "No hay herramientas habilitadas."; then
    ok "8. tools list confirma vacío/deshabilitado"
else
    fail_msg "8. tools list NO confirma vacío: $out8"
fi

# ---------------------------------------------------------------
# 9) execute con filename path traversal
# ---------------------------------------------------------------
run_fail "9. execute --mode desarrollo '../secreto' → rechazado" \
    "$OC" execute --mode desarrollo "../secreto"

# ---------------------------------------------------------------
# 10) workspace modo inválido
# ---------------------------------------------------------------
run_fail "10. ws init modo_invalido → rechazado" \
    "$WS" init "modo_invalido"

# ---------------------------------------------------------------
# 11) policy check pasa en estado sano
# ---------------------------------------------------------------
run_pass "11. policy check pasa en estado sano" "$PL" check

# ---------------------------------------------------------------
# 12) tools path/list/show responden sin habilitar herramientas
# ---------------------------------------------------------------
if "$TL" path >/dev/null 2>&1 && "$TL" list >/dev/null 2>&1 && "$TL" show >/dev/null 2>&1; then
    ok "12. tools path/list/show responden (sin habilitar nada)"
else
    fail_msg "12. tools path/list/show — alguno falló"
fi

# ---------------------------------------------------------------
# 13) Tools registry tampered (enabled: true) → contracts check FAIL
# ---------------------------------------------------------------
# Copiamos el registry vigente, mutamos cualquier 'enabled: false'
# a 'enabled: true' y apuntamos PATRICK_OS_TOOLS al archivo roto.
# El validador de contratos tiene que rechazar.
CT="$script_dir/openclaw-contracts.sh"
TAMPER_TOOLS=$(mktemp)
SOURCE_TOOLS="$("$TL" path 2>/dev/null || true)"
if [ -n "$SOURCE_TOOLS" ] && [ -f "$SOURCE_TOOLS" ]; then
    sed 's/enabled: false/enabled: true/g' "$SOURCE_TOOLS" > "$TAMPER_TOOLS"
else
    # Fallback: registry mínimo con una tool enabled.
    cat > "$TAMPER_TOOLS" <<'EOF_TT'
version: 1
default_state: disabled
tools:
  - name: read_file
    enabled: true
    description: dummy
    allowed_modes: [desarrollo]
    allowed_args: []
    denied_args: []
    filesystem_scope: "/tmp/"
    network: disabled
    sudo: disabled
    timeout_seconds: 5
    requires_confirmation: true
    log_level: audit
EOF_TT
fi
PATRICK_OS_TOOLS="$TAMPER_TOOLS" run_fail \
    "13. tools registry tampered (enabled: true) → contracts check blocked" \
    "$CT" check
rm -f "$TAMPER_TOOLS"

# ---------------------------------------------------------------
# 14) Simulate tool inexistente → FAIL (audit tool_unknown)
# ---------------------------------------------------------------
SIM="$script_dir/openclaw-simulate-tool.sh"
run_fail "14. simulate tool inexistente → rechazado" \
    "$SIM" unknown_tool_for_negtest

# ---------------------------------------------------------------
# 15) Simulate sobre registry tampered con enabled: true → FAIL
# ---------------------------------------------------------------
TAMPER_TOOLS2=$(mktemp)
if [ -n "$SOURCE_TOOLS" ] && [ -f "$SOURCE_TOOLS" ]; then
    sed 's/enabled: false/enabled: true/g' "$SOURCE_TOOLS" > "$TAMPER_TOOLS2"
else
    # Reuso del fallback de test 13.
    cat > "$TAMPER_TOOLS2" <<'EOF_TT2'
version: 1
default_state: disabled
tools:
  - name: read_file
    enabled: true
    description: dummy
    allowed_modes: [desarrollo]
    allowed_args: []
    denied_args: []
    filesystem_scope: "/tmp/"
    network: disabled
    sudo: disabled
    timeout_seconds: 5
    requires_confirmation: true
    log_level: audit
EOF_TT2
fi
PATRICK_OS_TOOLS="$TAMPER_TOOLS2" run_fail \
    "15. simulate sobre registry tampered (enabled: true) → rechazado" \
    "$SIM" read_file
rm -f "$TAMPER_TOOLS2"

# ---------------------------------------------------------------
# 16) Simulate herramienta conocida (disabled) → simulated-only
# ---------------------------------------------------------------
sim_out="$("$SIM" read_file 2>&1)"
sim_rc=$?
if [ "$sim_rc" -eq 0 ] && echo "$sim_out" | grep -q "Status: simulated-only"; then
    ok "16. simulate read_file → exit 0 con Status: simulated-only"
else
    fail_msg "16. simulate read_file falló (rc=$sim_rc o sin 'simulated-only' en output)"
    echo "$sim_out" | tail -n 6 | sed 's/^/        /'
fi

# ---------------------------------------------------------------
# 17-19) simulate-execute binding (plan aprobado + tool del registry)
# ---------------------------------------------------------------
# Generamos un plan dedicado para el binding. Por las dudas
# limpiamos cualquier sidecar .state previo (el plan recién creado
# no debería tener, pero defensivo).
"$OC" run --mode desarrollo --tag negtest-se --priority normal "plan para simulate-execute tests" > /dev/null 2>&1
SE_BASENAME=""
for p in "$SANDBOX/workspaces/desarrollo/plans/"*-plan.md; do
    [ -f "$p" ] && SE_BASENAME="$(basename "$p")"
done
if [ -n "$SE_BASENAME" ]; then
    rm -f "$SANDBOX/workspaces/desarrollo/plans/$SE_BASENAME.state"
fi

# 17) simulate-execute sin aprobación → blocked
if [ -z "$SE_BASENAME" ]; then
    fail_msg "17. (precondición rota) no se generó plan para simulate-execute"
else
    run_fail "17. simulate-execute sin aprobación → blocked" \
        "$OC" simulate-execute --mode desarrollo --tool read_file "$SE_BASENAME"
fi

# 18) approve + simulate-execute con tool conocida → simulated-only (exit 0)
if [ -n "$SE_BASENAME" ]; then
    "$WS" approve-plan desarrollo "$SE_BASENAME" > /dev/null 2>&1
    se_out="$("$OC" simulate-execute --mode desarrollo --tool read_file "$SE_BASENAME" 2>&1)"
    se_rc=$?
    if [ "$se_rc" -eq 0 ] && echo "$se_out" | grep -q "Status: simulated-only"; then
        ok "18. simulate-execute approved + read_file → exit 0 con Status: simulated-only"
    else
        fail_msg "18. simulate-execute approved (rc=$se_rc o sin 'simulated-only')"
        echo "$se_out" | tail -n 6 | sed 's/^/        /'
    fi
fi

# 19) simulate-execute aprobado con tool desconocida → fail
if [ -n "$SE_BASENAME" ]; then
    run_fail "19. simulate-execute --tool unknown_xyz → rechazado" \
        "$OC" simulate-execute --mode desarrollo --tool unknown_xyz "$SE_BASENAME"
fi

# ---------------------------------------------------------------
# 20) simulate-execute con filename traversal → rechazado por basename
# ---------------------------------------------------------------
run_fail "20. simulate-execute --mode desarrollo '../secreto' → rechazado" \
    "$OC" simulate-execute --mode desarrollo --tool read_file "../secreto"

# ---------------------------------------------------------------
# 21) simulate-execute approved genera manifest en executions/
# ---------------------------------------------------------------
# Re-aprovamos el plan de tests 17-18 si existe, y verificamos que
# el manifest correspondiente quedó escrito.
if [ -n "${SE_BASENAME:-}" ]; then
    "$OC" simulate-execute --mode desarrollo --tool read_file "$SE_BASENAME" > /dev/null 2>&1
    exec_dir="$SANDBOX/workspaces/desarrollo/executions"
    manifest_count=0
    for m in "$exec_dir"/*-manifest.md; do
        [ -f "$m" ] && manifest_count=$((manifest_count + 1))
    done
    if [ "$manifest_count" -ge 1 ]; then
        ok "21. simulate-execute approved generó manifest ($manifest_count en $exec_dir)"
    else
        fail_msg "21. simulate-execute approved NO generó manifest (esperado en $exec_dir)"
    fi
else
    fail_msg "21. (precondición rota) SE_BASENAME vacío de tests 17-19"
fi

# ---------------------------------------------------------------
# 22) ws show-execution latest funciona y contiene Result Section
# ---------------------------------------------------------------
se_show_out="$("$WS" show-execution desarrollo latest 2>&1)"
se_show_rc=$?
if [ "$se_show_rc" -eq 0 ] && echo "$se_show_out" | grep -q "No command executed."; then
    ok "22. ws show-execution latest imprime manifest con 'No command executed.'"
else
    fail_msg "22. ws show-execution latest falló (rc=$se_show_rc o sin 'No command executed.')"
    echo "$se_show_out" | tail -n 4 | sed 's/^/        /'
fi

# ---------------------------------------------------------------
# 23) ws show-execution con basename traversal → rechazado
# ---------------------------------------------------------------
run_fail "23. ws show-execution desarrollo '../bad' → rechazado" \
    "$WS" show-execution desarrollo "../bad"

# ---------------------------------------------------------------
# 24-26) Execution manifest index (creado por simulate-execute)
# ---------------------------------------------------------------
# A esta altura ya corrieron varios simulate-execute exitosos en
# tests 18 y 21, así que index.tsv debería existir.
idx_file="$SANDBOX/workspaces/desarrollo/executions/index.tsv"

# 24: index.tsv existe y tiene al menos 1 línea (el simulate-execute
# de tests 18/21 debió appendear).
if [ -f "$idx_file" ] && [ -s "$idx_file" ]; then
    idx_lines=$(wc -l < "$idx_file" | tr -d ' ')
    ok "24. simulate-execute crea executions/index.tsv ($idx_lines línea/s)"
else
    fail_msg "24. executions/index.tsv ausente o vacío en $idx_file"
fi

# 25: ws recent-executions imprime al menos 1 línea con read_file
rec_out="$("$WS" recent-executions desarrollo 2>&1)"
rec_rc=$?
if [ "$rec_rc" -eq 0 ] && echo "$rec_out" | grep -q "read_file"; then
    ok "25. ws recent-executions imprime al menos un entry con read_file"
else
    fail_msg "25. ws recent-executions (rc=$rec_rc o sin read_file en output)"
    echo "$rec_out" | tail -n 4 | sed 's/^/        /'
fi

# 26: ws search-executions read_file matchea
srch_out="$("$WS" search-executions desarrollo read_file 2>&1)"
srch_rc=$?
if [ "$srch_rc" -eq 0 ] && echo "$srch_out" | grep -q "read_file"; then
    ok "26. ws search-executions read_file → matchea"
else
    fail_msg "26. ws search-executions read_file (rc=$srch_rc o sin matches)"
    echo "$srch_out" | tail -n 4 | sed 's/^/        /'
fi

# ---------------------------------------------------------------
# 27-28) openclaw-report.sh consolida evidencia local
# ---------------------------------------------------------------
RP="$script_dir/openclaw-report.sh"
RP_OUT_FILE="$SANDBOX/openclaw-report.md"

# 27: report --out crea archivo. SKIP_NEGATIVE_TESTS inline para
# que report no llame al runner recursivamente.
PATRICK_DOCTOR_SKIP_NEGATIVE_TESTS=1 \
PATRICK_DOCTOR_SKIP_READINESS=1 \
PATRICK_DOCTOR_SKIP_REPORT=1 \
    "$RP" --mode desarrollo --out "$RP_OUT_FILE" > /dev/null 2>&1
if [ -f "$RP_OUT_FILE" ] && grep -q "^# OpenClaw Report$" "$RP_OUT_FILE"; then
    ok "27. report --out genera archivo con header markdown"
else
    fail_msg "27. report --out NO generó archivo válido en $RP_OUT_FILE"
fi

# 28: report contiene ready_for_real_execution=no
if [ -f "$RP_OUT_FILE" ] && grep -q "^\* ready_for_real_execution=no$" "$RP_OUT_FILE"; then
    ok "28. report contiene 'ready_for_real_execution=no'"
else
    fail_msg "28. report NO contiene 'ready_for_real_execution=no'"
fi

echo
echo "Resumen: OK=$ok_count FAIL=$fail_count"
exit "$fail_count"
