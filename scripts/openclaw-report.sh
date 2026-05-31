#!/usr/bin/env bash
# openclaw-report.sh — reporte consolidado local de OpenClaw para
# revisar planes, ejecuciones simuladas, manifests, audit log,
# readiness y negative tests en un solo documento markdown. NO
# ejecuta herramientas reales: solo concatena salidas de scripts
# ya auditados del repo.
#
# Uso:
#   openclaw-report.sh                             (stdout, modo desarrollo)
#   openclaw-report.sh --mode <modo>
#   openclaw-report.sh --out <archivo.md>
#   openclaw-report.sh --mode <modo> --out <archivo.md>
#
# Si --out se da, escribe al archivo (creando dirs padres si hace
# falta) e imprime la ruta. Si no, escribe a stdout.

set -uo pipefail

script_dir="$(cd "$(dirname "$0")" && pwd)"

MODE="desarrollo"
OUT=""

while [ "$#" -gt 0 ]; do
    case "${1:-}" in
        --mode)
            shift || true
            if [ -z "${1:-}" ] || [[ "${1:-}" == --* ]]; then
                echo "Error: --mode requiere un valor." >&2; exit 1
            fi
            MODE="$1"; shift || true
            ;;
        --out)
            shift || true
            if [ -z "${1:-}" ] || [[ "${1:-}" == --* ]]; then
                echo "Error: --out requiere un valor." >&2; exit 1
            fi
            OUT="$1"; shift || true
            ;;
        *)
            echo "Error: arg desconocido '$1'." >&2
            echo "Uso: openclaw-report.sh [--mode <m>] [--out <file>]" >&2
            exit 1
            ;;
    esac
done

OS_HOME="${PATRICK_OS_HOME:-$HOME/.patrick-os}"
fecha="$(date '+%Y-%m-%d %H:%M:%S')"

# Detectar si entramos desde una cadena (negative-tests test 27/28
# llama report; o doctor report smoke). En ese caso saltamos la
# sección Negative tests del reporte para no entrar en loop
# report → NT → report. Los flags solo se exportan inline al
# subprocess de readiness (que llamamos abajo) — no como export
# global, para que NUESTRA detección no se vea contaminada.
REPORT_FROM_CHAIN=0
if [ -n "${PATRICK_DOCTOR_SKIP_NEGATIVE_TESTS:-}" ] \
   || [ -n "${PATRICK_DOCTOR_SKIP_REPORT:-}" ]; then
    REPORT_FROM_CHAIN=1
fi

PL="$script_dir/openclaw-policy.sh"
CT="$script_dir/openclaw-contracts.sh"
TL="$script_dir/openclaw-tools.sh"
WS="$script_dir/workspace.sh"
AU="$script_dir/openclaw-audit.sh"
RD="$script_dir/openclaw-readiness.sh"
NT="$script_dir/openclaw-negative-tests.sh"

# Cachear readiness — es lo más caro (corre toda la cadena) y lo
# usamos dos veces (estado general + conclusión). Los SKIP_* van
# inline para que el readiness hijo (y su doctor/negative-tests
# anidados) salten smokes recursivos. Nuestro env no se contamina.
RD_OUT="$(PATRICK_DOCTOR_SKIP_REPORT=1 \
          PATRICK_DOCTOR_SKIP_READINESS=1 \
          PATRICK_DOCTOR_SKIP_NEGATIVE_TESTS=1 \
          "$RD" beta1 2>&1)"
RD_RC=$?

generate_report() {
    cat <<EOF_HDR
# OpenClaw Report

## Metadata

Fecha: $fecha
PATRICK_OS_HOME: $OS_HOME
Modo: $MODE

## Estado general

EOF_HDR

    if "$PL" check >/dev/null 2>&1; then
        echo "* Policy: OK"
    else
        echo "* Policy: FAIL"
    fi

    if "$TL" list 2>/dev/null | grep -q "No hay herramientas habilitadas."; then
        echo "* Tools registry: ninguna habilitada"
    else
        echo "* Tools registry: contenido inesperado"
    fi

    if "$CT" check >/dev/null 2>&1; then
        echo "* Contracts: OK"
    else
        echo "* Contracts: FAIL"
    fi

    ks_file="$OS_HOME/openclaw/KILL_SWITCH"
    if [ -f "$ks_file" ]; then
        echo "* Kill switch: active ($ks_file)"
    else
        echo "* Kill switch: inactive"
    fi

    if [ "$RD_RC" -eq 0 ]; then
        echo "* Readiness: OK"
    else
        echo "* Readiness: FAIL"
    fi
    echo "* Real execution: disabled"
    echo

    echo '## Últimos planes'
    echo
    echo '```'
    "$WS" recent "$MODE" 5 2>&1 || true
    echo '```'
    echo

    echo '## Últimas ejecuciones simuladas'
    echo
    echo '```'
    "$WS" recent-executions "$MODE" 5 2>&1 || true
    echo '```'
    echo

    echo '## Audit summary'
    echo
    echo '```'
    "$AU" summary 2>&1 || true
    echo '```'
    echo

    echo '## Readiness'
    echo
    echo '```'
    # Salida resumida: solo líneas con marca [OK|FAIL|BLOCKED|INFO]
    # y las clave del Resumen + ready_for_*.
    echo "$RD_OUT" | grep -E '^\[(OK|FAIL|BLOCKED|INFO)\]|^Resumen:|^ready_for_' || true
    echo '```'
    echo

    echo '## Negative tests'
    echo
    echo '```'
    if [ "$REPORT_FROM_CHAIN" = "1" ]; then
        # Si entramos desde negative-tests (cadena nt → report),
        # NO re-correr el runner — loop infinito. El caller ya está
        # corriendo la suite; reportamos esa relación.
        echo "(saltado: report invocado desde negative-tests; el caller corre la suite)"
    else
        "$NT" 2>&1 | grep -E '^\[(OK|FAIL)\]|^Resumen:' || true
    fi
    echo '```'
    echo

    echo '## Conclusión'
    echo
    if echo "$RD_OUT" | grep -q '^ready_for_simulated_beta1=yes$'; then
        echo '* ready_for_simulated_beta1=yes'
    else
        echo '* ready_for_simulated_beta1=no'
    fi
    echo '* ready_for_real_execution=no'
    echo '* runtime real sigue no implementado'
}

if [ -n "$OUT" ]; then
    mkdir -p "$(dirname "$OUT")"
    generate_report > "$OUT"
    echo "$OUT"
else
    generate_report
fi
