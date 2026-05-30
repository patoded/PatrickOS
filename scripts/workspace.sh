#!/usr/bin/env bash
# workspace.sh — gestión local de workspaces por modo. NO ejecuta
# herramientas, NO toca red, NO escala privilegios. Es la base concreta
# del aislamiento por modo que pide OpenClaw Beta-0 (ver
# docs/OPENCLAW_BETA0_SPEC.md): openclaw-stub.sh delega aquí la creación
# del workspace antes de escribir su plan.
#
# Uso:
#   workspace.sh list
#   workspace.sh init <modo>
#   workspace.sh clean <modo> [--yes]
#   workspace.sh path <modo>
#
# Modos permitidos: consulta, clase, video, desarrollo, ia, general
#
# Base: $PATRICK_OS_HOME/workspaces/<modo>/  (default $HOME/.patrick-os)

set -euo pipefail

OS_HOME="${PATRICK_OS_HOME:-$HOME/.patrick-os}"
WORKSPACES_DIR="$OS_HOME/workspaces"
ALLOWED_MODES=(consulta clase video desarrollo ia general)

usage() {
    cat <<'EOF'
Uso:
  workspace.sh list
  workspace.sh init <modo>
  workspace.sh clean <modo> [--yes]
  workspace.sh path <modo>

Modos permitidos: consulta, clase, video, desarrollo, ia, general
EOF
}

mode_allowed() {
    local m="$1"
    for am in "${ALLOWED_MODES[@]}"; do
        [ "$am" = "$m" ] && return 0
    done
    return 1
}

require_mode() {
    if [ -z "${1:-}" ]; then
        echo "Error: falta <modo>." >&2
        usage >&2
        exit 1
    fi
    if ! mode_allowed "$1"; then
        echo "Error: modo '$1' no permitido." >&2
        echo "Modos permitidos: ${ALLOWED_MODES[*]}" >&2
        exit 1
    fi
}

write_readme() {
    local mode="$1"
    local ws_dir="$2"
    cat > "$ws_dir/README.md" <<EOF_README
# PatrickOS Workspace
Modo: $mode
Creado: $(date '+%Y-%m-%d %H:%M:%S')
Estado: local
EOF_README
}

cmd="${1:-}"
shift || true

case "$cmd" in
    list)
        if [ ! -d "$WORKSPACES_DIR" ]; then
            echo "Sin workspaces."
            exit 0
        fi
        # Una línea por modo presente. Solo dirs; archivos sueltos
        # en la raíz de workspaces/ se ignoran a propósito.
        found=0
        for d in "$WORKSPACES_DIR"/*/; do
            [ -d "$d" ] || continue
            found=1
            name="$(basename "$d")"
            printf '%s  %s\n' "$name" "$d"
        done
        # if explícito en vez de "[ ] && echo": bajo 'set -e' el test
        # como última instrucción del case puede propagar exit 1
        # según cómo se invoque el script.
        if [ "$found" -eq 0 ]; then
            echo "Sin workspaces."
        fi
        ;;
    init)
        mode="${1:-}"
        require_mode "$mode"
        ws_dir="$WORKSPACES_DIR/$mode"
        mkdir -p "$ws_dir"
        # Idempotente: si ya hay README, no lo pisamos (puede tener
        # ediciones del usuario). Para resetear, usar 'clean --yes'.
        if [ ! -f "$ws_dir/README.md" ]; then
            write_readme "$mode" "$ws_dir"
        fi
        echo "Workspace listo: $ws_dir"
        ;;
    clean)
        mode="${1:-}"
        require_mode "$mode"
        shift || true
        confirm="${1:-}"
        if [ "$confirm" != "--yes" ]; then
            echo "Para limpiar, usa: scripts/workspace.sh clean $mode --yes"
            exit 1
        fi
        ws_dir="$WORKSPACES_DIR/$mode"
        if [ ! -d "$ws_dir" ]; then
            mkdir -p "$ws_dir"
        else
            # Vaciar contenido (incluye dotfiles) sin borrar el dir mismo.
            # mindepth 1 evita borrar $ws_dir; -delete trabaja bottom-up.
            find "$ws_dir" -mindepth 1 -delete
        fi
        write_readme "$mode" "$ws_dir"
        echo "Workspace limpio: $ws_dir"
        ;;
    path)
        mode="${1:-}"
        require_mode "$mode"
        echo "$WORKSPACES_DIR/$mode"
        ;;
    "")
        usage >&2
        exit 1
        ;;
    *)
        echo "Subcomando desconocido: $cmd" >&2
        usage >&2
        exit 1
        ;;
esac
