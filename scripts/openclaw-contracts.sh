#!/usr/bin/env bash
# openclaw-contracts.sh — validador de contratos de herramientas para
# OpenClaw Beta-1 (sin habilitar ejecución real). Lee
# configs/openclaw-tools.yaml y verifica:
#
#   1. Invariantes baseline: 'version: 1', 'default_state: disabled'.
#   2. Si 'tools: []' (Beta-0): listo, registry vacío/deshabilitado.
#   3. Si tools NO vacío: shape mínima por entrada (11 campos del
#      contrato declarado en docs/OPENCLAW_TOOL_CONTRACTS.md) y
#      reglas duras de seguridad (sudo prohibido true/enabled,
#      network prohibido enabled, name solo [a-z][a-z0-9_]*).
#
# NO interpreta valores YAML completos (sin parser yq/python-yaml);
# usa grep + awk para validación de presencia y reglas literales.
# Suficiente para el contrato chico y predecible de Beta-0/Beta-1.
#
# Uso:
#   openclaw-contracts.sh path     ruta del openclaw-tools.yaml
#   openclaw-contracts.sh show     imprime el YAML
#   openclaw-contracts.sh check    valida; exit 0 OK, 1 si falla
#   openclaw-contracts.sh          (alias de check)
#
# Búsqueda del archivo:
#   1. $PATRICK_OS_TOOLS
#   2. <repo>/configs/openclaw-tools.yaml
#   3. /usr/local/share/patrick-os/configs/openclaw-tools.yaml

set -uo pipefail

script_dir="$(cd "$(dirname "$0")" && pwd)"

TOOLS=""
if [ -n "${PATRICK_OS_TOOLS:-}" ] && [ -f "$PATRICK_OS_TOOLS" ]; then
    TOOLS="$PATRICK_OS_TOOLS"
elif [ -f "$(dirname "$script_dir")/configs/openclaw-tools.yaml" ]; then
    TOOLS="$(dirname "$script_dir")/configs/openclaw-tools.yaml"
elif [ -f "/usr/local/share/patrick-os/configs/openclaw-tools.yaml" ]; then
    TOOLS="/usr/local/share/patrick-os/configs/openclaw-tools.yaml"
fi

cmd="${1:-check}"

case "$cmd" in
    path)
        if [ -z "$TOOLS" ]; then
            echo "Error: openclaw-tools.yaml no encontrada." >&2; exit 1
        fi
        echo "$TOOLS"
        ;;
    show)
        if [ -z "$TOOLS" ]; then
            echo "Error: openclaw-tools.yaml no encontrada." >&2; exit 1
        fi
        echo "# tools: $TOOLS"
        cat "$TOOLS"
        ;;
    check)
        echo "OpenClaw Tool Contracts check"
        if [ -z "$TOOLS" ]; then
            echo "[FAIL] openclaw-tools.yaml no encontrada (sin registry = sin contrato)" >&2
            exit 1
        fi
        echo "tools: $TOOLS"
        echo

        fail=0
        ok() { echo "[OK]   $1"; }
        fail_msg() { echo "[FAIL] $1"; fail=$((fail + 1)); }

        # 1) Baseline invariants.
        if grep -qE '^version:[[:space:]]+1[[:space:]]*$' "$TOOLS"; then
            ok "version: 1"
        else
            fail_msg "version: 1 (no encuentro línea exacta)"
        fi
        if grep -qE '^default_state:[[:space:]]+disabled[[:space:]]*$' "$TOOLS"; then
            ok "default_state: disabled"
        else
            fail_msg "default_state: disabled (no encuentro línea exacta)"
        fi

        # 2) Beta-0 fast path: tools: [].
        if grep -qE '^tools:[[:space:]]*\[\][[:space:]]*$' "$TOOLS"; then
            ok "tool registry disabled/empty"
            echo
            if [ "$fail" -gt 0 ]; then
                echo "Resultado: FAIL ($fail invariante/s baseline)." >&2
                exit 1
            fi
            echo "Resultado: OK. Baseline contractual intacto. Registry vacío — sin ejecución habilitada."
            exit 0
        fi

        # 3) Tools no vacío: shape mínima por entrada + reglas duras.
        # No interpretamos valores; verificamos que cada bloque (que
        # arranca con '^  - name:') liste los 12 nombres de campo del
        # contrato. awk delimita bloque por bloque.
        echo "[INFO] tools registry no vacío — validando shape de cada entrada"

        shape_out=$(awk '
            BEGIN {
                # 12 campos del contrato (ver OPENCLAW_TOOL_CONTRACTS.md).
                # enabled se agregó en v0.4 para diferenciar candidatas
                # disabled de tools efectivamente habilitadas.
                split("name enabled description allowed_modes allowed_args denied_args filesystem_scope network sudo timeout_seconds requires_confirmation log_level", req, " ")
            }
            function flush_block(   missing, i) {
                if (block_name == "") return
                missing = ""
                for (i in req) {
                    if (!(req[i] in present)) {
                        missing = missing " " req[i]
                    }
                }
                if (missing == "") {
                    printf "OK %s\n", block_name
                } else {
                    printf "BAD %s missing:%s\n", block_name, missing
                }
            }
            /^  - name:/ {
                flush_block()
                block_name = $0
                sub(/^  - name:[[:space:]]+/, "", block_name)
                delete present
                present["name"] = 1
                next
            }
            block_name != "" && /^    [a-z_]+:/ {
                field = $1
                sub(/:.*/, "", field)
                present[field] = 1
            }
            END { flush_block() }
        ' "$TOOLS")

        if [ -z "$shape_out" ]; then
            fail_msg "tools no vacío pero no detecté bloques '  - name:' válidos"
        else
            while IFS= read -r line; do
                case "$line" in
                    "OK "*)
                        ok "tool '${line#OK }': 12 campos del contrato presentes"
                        ;;
                    "BAD "*)
                        rest="${line#BAD }"
                        name="${rest%% missing:*}"
                        miss="${rest##* missing:}"
                        fail_msg "tool '$name': faltan campos:$miss"
                        ;;
                esac
            done <<< "$shape_out"
        fi

        # 4) Reglas duras de seguridad (independientes de la shape).
        if grep -qE '^[[:space:]]+sudo:[[:space:]]+(true|enabled)[[:space:]]*$' "$TOOLS"; then
            fail_msg "alguna tool declara sudo: true|enabled (prohibido)"
        else
            ok "ninguna tool declara sudo true/enabled"
        fi
        if grep -qE '^[[:space:]]+network:[[:space:]]+enabled[[:space:]]*$' "$TOOLS"; then
            fail_msg "alguna tool declara network: enabled (prohibido sin PR específico)"
        else
            ok "ninguna tool declara network enabled"
        fi
        # enabled: ninguna tool puede declarar 'enabled: true'. Beta-0/
        # v0.4 mantiene todas las candidatas disabled. Habilitar
        # requiere PR explícito que actualice safety model + Beta-1 plan.
        if grep -qE '^[[:space:]]+enabled:[[:space:]]+true[[:space:]]*$' "$TOOLS"; then
            fail_msg "alguna tool declara enabled: true (prohibido en Beta-0/v0.4)"
        else
            ok "ninguna tool declara enabled true"
        fi
        # requires_confirmation: la regla dura es 'true' por contrato.
        # Cualquier 'requires_confirmation: false' es señal de que
        # alguien quiso saltarse el human gate.
        if grep -qE '^[[:space:]]+requires_confirmation:[[:space:]]+false[[:space:]]*$' "$TOOLS"; then
            fail_msg "alguna tool declara requires_confirmation: false (prohibido)"
        else
            ok "todas las tools exigen requires_confirmation: true"
        fi
        # name debe matchear [a-z][a-z0-9_]*. Buscamos las líneas
        # '  - name: <valor>' y validamos el valor por sí mismo.
        bad_names=$(grep -E '^  - name:[[:space:]]+' "$TOOLS" \
                    | sed -E 's/^  - name:[[:space:]]+//' \
                    | grep -Ev '^[a-z][a-z0-9_]*$' || true)
        if [ -n "$bad_names" ]; then
            fail_msg "name con caracteres inseguros: $(echo "$bad_names" | tr '\n' ' ')"
        else
            ok "todos los names usan [a-z][a-z0-9_]*"
        fi
        # allowed_modes: cada valor inline debe estar en el set fijo
        # de modos. Soportamos formato '[a, b, c]' (sin newlines en el
        # campo); las candidatas Beta-1 usan ese formato.
        bad_modes=$(awk '
            /^  - name:/ {
                block = $0; sub(/^  - name:[[:space:]]+/, "", block)
            }
            /^[[:space:]]+allowed_modes:[[:space:]]*\[/ {
                line = $0
                sub(/^[[:space:]]+allowed_modes:[[:space:]]*\[/, "", line)
                sub(/\].*$/, "", line)
                gsub(/[[:space:]]/, "", line)
                n = split(line, modes, ",")
                for (i = 1; i <= n; i++) {
                    if (modes[i] == "") continue
                    if (modes[i] !~ /^(consulta|clase|video|desarrollo|ia|general)$/) {
                        printf "%s:%s\n", block, modes[i]
                    }
                }
            }
        ' "$TOOLS")
        if [ -n "$bad_modes" ]; then
            while IFS= read -r bm; do
                fail_msg "tool '${bm%:*}': allowed_modes contiene modo no permitido '${bm#*:}'"
            done <<< "$bad_modes"
        else
            ok "allowed_modes solo usa valores del set permitido"
        fi

        echo
        if [ "$fail" -gt 0 ]; then
            echo "Resultado: FAIL ($fail invariante/s rota/s). NO habilitar herramienta hasta corregir." >&2
            exit 1
        fi
        echo "Resultado: OK. Contratos válidos (shape + reglas duras). Tools candidatas presentes, todas disabled. Habilitar runtime real sigue requiriendo PR específico."
        ;;
    *)
        echo "Uso: $0 {path|show|check}" >&2
        exit 1
        ;;
esac
