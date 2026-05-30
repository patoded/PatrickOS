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
  workspace.sh plans <modo>
  workspace.sh last-plan <modo>
  workspace.sh show-plan <modo> <archivo|latest>
  workspace.sh plan-index <modo>
  workspace.sh recent <modo> [n]
  workspace.sh search <modo> <texto>

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
    plans)
        mode="${1:-}"
        require_mode "$mode"
        plans_dir="$WORKSPACES_DIR/$mode/plans"
        if [ ! -d "$plans_dir" ]; then
            echo "Sin planes."
            exit 0
        fi
        # Glob *-plan.md: si no matchea nada, $f queda con el patrón
        # literal — el '[ -f ]' lo descarta y reportamos "Sin planes."
        found=0
        for f in "$plans_dir"/*-plan.md; do
            [ -f "$f" ] || continue
            found=1
            echo "$f"
        done
        if [ "$found" -eq 0 ]; then
            echo "Sin planes."
        fi
        ;;
    last-plan)
        mode="${1:-}"
        require_mode "$mode"
        plan="$WORKSPACES_DIR/$mode/last-plan.md"
        if [ ! -f "$plan" ]; then
            echo "Sin last-plan."
            exit 0
        fi
        cat "$plan"
        ;;
    plan-index)
        mode="${1:-}"
        require_mode "$mode"
        idx="$WORKSPACES_DIR/$mode/plans/index.tsv"
        if [ ! -f "$idx" ]; then
            echo "Sin índice de planes."
            exit 0
        fi
        cat "$idx"
        ;;
    recent)
        mode="${1:-}"
        require_mode "$mode"
        shift || true
        n="${1:-5}"
        if ! [[ "$n" =~ ^[0-9]+$ ]]; then
            echo "Error: n debe ser entero. Recibido: '$n'." >&2
            exit 1
        fi
        idx="$WORKSPACES_DIR/$mode/plans/index.tsv"
        if [ ! -f "$idx" ]; then
            echo "Sin planes."
            exit 0
        fi
        # Reformatear las últimas N entradas del índice TSV:
        # timestamp | filename | task   (omitimos el modo: redundante).
        tail -n "$n" "$idx" | awk -F'\t' '{printf "%s | %s | %s\n", $1, $3, $4}'
        ;;
    search)
        mode="${1:-}"
        require_mode "$mode"
        shift || true
        needle="${*:-}"
        needle="${needle#"${needle%%[![:space:]]*}"}"
        needle="${needle%"${needle##*[![:space:]]}"}"
        if [ -z "$needle" ]; then
            echo "Error: falta texto a buscar. Uso: workspace.sh search <modo> <texto>" >&2
            exit 1
        fi
        idx="$WORKSPACES_DIR/$mode/plans/index.tsv"
        if [ ! -f "$idx" ]; then
            echo "Sin coincidencias."
            exit 0
        fi
        # grep -iF: case-insensitive, fixed-string (sin regex; el
        # needle puede contener . * etc. sin sorpresas). -- corta
        # opciones por si el usuario busca algo que arranca con '-'.
        # || true porque grep retorna 1 sin matches y no queremos
        # tumbar el script.
        matches=$(grep -iF -- "$needle" "$idx" || true)
        if [ -z "$matches" ]; then
            echo "Sin coincidencias."
            exit 0
        fi
        echo "$matches" | awk -F'\t' '{printf "%s | %s | %s\n", $1, $3, $4}'
        ;;
    show-plan)
        mode="${1:-}"
        require_mode "$mode"
        shift || true
        target="${1:-}"
        if [ -z "$target" ]; then
            echo "Error: falta archivo. Uso: workspace.sh show-plan <modo> <archivo|latest>" >&2
            exit 1
        fi
        ws_dir="$WORKSPACES_DIR/$mode"
        if [ "$target" = "latest" ]; then
            plan="$ws_dir/last-plan.md"
        else
            # Solo basename. Sin '/', sin '..' — no permitimos path
            # traversal ni rutas absolutas, así show-plan no puede leer
            # nada fuera de <workspace>/plans/.
            case "$target" in
                */*|*..*)
                    echo "Error: solo se permite basename (sin '/' ni '..'): '$target'" >&2
                    exit 1
                    ;;
            esac
            plan="$ws_dir/plans/$target"
        fi
        if [ ! -f "$plan" ]; then
            echo "Error: plan no encontrado: $plan" >&2
            exit 1
        fi
        cat "$plan"
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
