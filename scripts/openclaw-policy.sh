#!/usr/bin/env bash
# openclaw-policy.sh — capa de política explícita para OpenClaw.
# NO ejecuta herramientas, NO toca red, NO escala privilegios. Es un
# gate de lectura/validación contra configs/openclaw-policy.yaml.
# openclaw-stub.sh la invoca antes de cada 'run' para abortar si la
# policy permitiría algo inseguro (red, sudo, plugins, marketplace,
# tool whitelist no vacía o kill switch desactivado).
#
# Uso:
#   openclaw-policy.sh show     imprime el contenido de la policy
#   openclaw-policy.sh path     imprime la ruta usada
#   openclaw-policy.sh check    valida invariantes; exit 0 OK, 1 si falla
#   openclaw-policy.sh          (alias de show)
#
# Búsqueda de la policy (primer hit gana):
#   1. $PATRICK_OS_POLICY (override explícito)
#   2. <repo>/configs/openclaw-policy.yaml (si script_dir está en el repo)
#   3. /usr/local/share/patrick-os/configs/openclaw-policy.yaml (instalación)

set -uo pipefail

script_dir="$(cd "$(dirname "$0")" && pwd)"

# Localización. El repo se infiere por convención: si script_dir/.. tiene
# configs/openclaw-policy.yaml, ese es el repo; si no, caemos a la ruta
# instalada. El override por env gana siempre.
POLICY=""
if [ -n "${PATRICK_OS_POLICY:-}" ] && [ -f "$PATRICK_OS_POLICY" ]; then
    POLICY="$PATRICK_OS_POLICY"
elif [ -f "$(dirname "$script_dir")/configs/openclaw-policy.yaml" ]; then
    POLICY="$(dirname "$script_dir")/configs/openclaw-policy.yaml"
elif [ -f "/usr/local/share/patrick-os/configs/openclaw-policy.yaml" ]; then
    POLICY="/usr/local/share/patrick-os/configs/openclaw-policy.yaml"
fi

cmd="${1:-show}"

case "$cmd" in
    path)
        if [ -z "$POLICY" ]; then
            echo "Error: policy no encontrada (probé \$PATRICK_OS_POLICY, repo/configs/, /usr/local/share/...)." >&2
            exit 1
        fi
        echo "$POLICY"
        ;;
    show)
        if [ -z "$POLICY" ]; then
            echo "Error: policy no encontrada." >&2
            exit 1
        fi
        echo "# policy: $POLICY"
        cat "$POLICY"
        ;;
    check)
        echo "OpenClaw policy check"
        if [ -z "$POLICY" ]; then
            echo "[FAIL] policy no encontrada (sin policy = sin gate; abortando)" >&2
            exit 1
        fi
        echo "policy: $POLICY"
        echo

        fail=0
        ok()       { echo "[OK]   $1"; }
        fail_msg() { echo "[FAIL] $1"; fail=$((fail + 1)); }

        # Cada invariante = una línea literal en el YAML. Evitamos parser
        # YAML real para no agregar dep (yq/python-yaml); el shape de la
        # policy es chico y predecible, y cualquier desviación visual ya
        # cuenta como sospechosa. Usamos [[:space:]] en vez de \s para
        # ser portables entre GNU grep y BSD grep.
        require_line() {
            local label="$1"
            local pattern="$2"
            if grep -qE "$pattern" "$POLICY"; then
                ok "$label"
            else
                fail_msg "$label (no encuentro línea que matchee: $pattern)"
            fi
        }

        require_line "network: disabled"     '^network:[[:space:]]+disabled[[:space:]]*$'
        require_line "sudo: disabled"        '^sudo:[[:space:]]+disabled[[:space:]]*$'
        require_line "plugins: disabled"     '^plugins:[[:space:]]+disabled[[:space:]]*$'
        require_line "marketplace: disabled" '^marketplace:[[:space:]]+disabled[[:space:]]*$'
        require_line "tool_whitelist: []"    '^tool_whitelist:[[:space:]]*\[\][[:space:]]*$'
        require_line "kill_switch: true"     '^kill_switch:[[:space:]]+true[[:space:]]*$'

        # Kill switch local: independiente de la policy YAML. La policy
        # describe lo que DEBERÍA ser; el kill switch es una pausa
        # táctica del usuario. Lo reportamos como [INFO] para que se vea
        # en el log, pero no cuenta como FAIL — la policy puede seguir
        # siendo válida con el sistema pausado.
        ks="${PATRICK_OS_HOME:-$HOME/.patrick-os}/openclaw/KILL_SWITCH"
        if [ -f "$ks" ]; then
            echo "[INFO] KILL_SWITCH activo: $ks (OpenClaw run está bloqueado por el usuario)"
        fi

        # Tool registry (configs/openclaw-tools.yaml): ver
        # docs/OPENCLAW_TOOL_CONTRACTS.md. En Beta-0 la lista debe
        # estar vacía y default_state=disabled. Si el archivo no
        # existe todavía (instalación vieja), no fallamos — es un
        # invariante futuro, no un control crítico para Beta-0
        # dry-run. Si existe, exigimos las dos invariantes.
        tools_yaml=""
        if [ -n "${PATRICK_OS_TOOLS:-}" ] && [ -f "$PATRICK_OS_TOOLS" ]; then
            tools_yaml="$PATRICK_OS_TOOLS"
        elif [ -f "$(dirname "$script_dir")/configs/openclaw-tools.yaml" ]; then
            tools_yaml="$(dirname "$script_dir")/configs/openclaw-tools.yaml"
        elif [ -f "/usr/local/share/patrick-os/configs/openclaw-tools.yaml" ]; then
            tools_yaml="/usr/local/share/patrick-os/configs/openclaw-tools.yaml"
        fi
        if [ -n "$tools_yaml" ]; then
            # Reglas mínimas que el policy gate exige al registry:
            #   - default_state: disabled (siempre)
            #   - ningún 'enabled: true' (Beta-0/v0.4 mantiene todas
            #     las candidatas disabled)
            # Validación profunda (12 campos, allowed_modes válidos,
            # requires_confirmation true, etc.) vive en
            # openclaw-contracts.sh; acá solo cortamos lo que volaría
            # cualquier 'claw run' en sí.
            if grep -qE '^default_state:[[:space:]]+disabled[[:space:]]*$' "$tools_yaml" \
               && ! grep -qE '^[[:space:]]+enabled:[[:space:]]+true[[:space:]]*$' "$tools_yaml"; then
                ok "tool registry: ningún tool enabled ($tools_yaml)"
            else
                fail_msg "tool registry ($tools_yaml) inseguro: default_state debe ser 'disabled' y ningún tool puede declarar 'enabled: true'"
            fi
        fi

        echo
        if [ "$fail" -gt 0 ]; then
            echo "Resultado: FAIL ($fail invariante/s rota/s). NO ejecutar OpenClaw run hasta corregir." >&2
            exit 1
        fi
        echo "Resultado: OK. Todas las invariantes seguras se mantienen."
        ;;
    *)
        echo "Uso: $0 {show|path|check}" >&2
        exit 1
        ;;
esac
