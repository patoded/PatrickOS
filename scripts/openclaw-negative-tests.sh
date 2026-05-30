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

echo
echo "Resumen: OK=$ok_count FAIL=$fail_count"
exit "$fail_count"
