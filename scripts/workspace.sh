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
  workspace.sh filter-tag <modo> <tag>
  workspace.sh filter-priority <modo> <low|normal|high>
  workspace.sh approve-plan <modo> <filename>
  workspace.sh reject-plan <modo> <filename> [razón]
  workspace.sh plan-status <modo> <filename>
  workspace.sh executions <modo>
  workspace.sh last-execution <modo>
  workspace.sh show-execution <modo> <archivo|latest>
  workspace.sh execution-index <modo>
  workspace.sh recent-executions <modo> [n]
  workspace.sh search-executions <modo> <texto>

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

# Validación de basename para subcomandos que reciben filename:
# rechaza vacío, cualquier '/', y cualquier '..' embebido. Así
# show-plan / approve-plan / etc. no pueden escapar de
# <workspace>/plans/.
require_basename() {
    case "${1:-}" in
        ""|*/*|*..*)
            echo "Error: filename inválido (solo basename, sin '/' ni '..'): '${1:-}'" >&2
            exit 1
            ;;
    esac
}

# Escribe el sidecar <plan>.state con status, timestamp y razón
# opcional. Sobrescribe a propósito: 'approve' después de 'reject'
# (o viceversa) refleja el cambio de decisión del usuario.
write_state() {
    local plan_file="$1"
    local status="$2"
    local reason="${3:-}"
    local state_file="${plan_file}.state"
    {
        printf 'status=%s\n' "$status"
        printf 'timestamp=%s\n' "$(date '+%Y-%m-%d %H:%M:%S')"
        if [ -n "$reason" ]; then
            # Strip newlines defensivos: el formato es key=value por
            # línea, una razón con \n rompería el parseo.
            local reason_clean
            reason_clean="$(printf '%s' "$reason" | tr -d '\n\r')"
            printf 'reason=%s\n' "$reason_clean"
        fi
    } > "$state_file"
}

# Reformatea líneas TSV de index.tsv (desde stdin) al output visible
# de los comandos de lectura:
#   timestamp | filename | tag | priority | status | task
# Tolera índices viejos de 4 columnas (tag/priority defaults). El
# status sale del sidecar <plans_dir>/<file>.state si existe; si no,
# es 'pending'.
format_index_lines() {
    local plans_dir="$1"
    awk -F'\t' -v plans_dir="$plans_dir" '
        {
            if (NF >= 6) {
                ts=$1; file=$3; tag=$4; prio=$5; task=$6
            } else {
                ts=$1; file=$3; tag="general"; prio="normal"; task=$4
            }
            sidecar = plans_dir "/" file ".state"
            status = "pending"
            while ((getline line < sidecar) > 0) {
                if (line ~ /^status=/) {
                    sub(/^status=/, "", line)
                    status = line
                    break
                }
            }
            close(sidecar)
            printf "%s | %s | %s | %s | %s | %s\n", ts, file, tag, prio, status, task
        }'
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
        plans_dir="$WORKSPACES_DIR/$mode/plans"
        idx="$plans_dir/index.tsv"
        if [ ! -f "$idx" ]; then
            echo "Sin índice de planes."
            exit 0
        fi
        format_index_lines "$plans_dir" < "$idx"
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
        plans_dir="$WORKSPACES_DIR/$mode/plans"
        idx="$plans_dir/index.tsv"
        if [ ! -f "$idx" ]; then
            echo "Sin planes."
            exit 0
        fi
        tail -n "$n" "$idx" | format_index_lines "$plans_dir"
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
        plans_dir="$WORKSPACES_DIR/$mode/plans"
        idx="$plans_dir/index.tsv"
        if [ ! -f "$idx" ]; then
            echo "Sin coincidencias."
            exit 0
        fi
        # grep -iF: case-insensitive, fixed-string. -- corta opciones
        # por si el needle arranca con '-'. || true para no abortar
        # cuando no hay matches.
        matches=$(grep -iF -- "$needle" "$idx" || true)
        if [ -z "$matches" ]; then
            echo "Sin coincidencias."
            exit 0
        fi
        printf '%s\n' "$matches" | format_index_lines "$plans_dir"
        ;;
    filter-tag)
        mode="${1:-}"
        require_mode "$mode"
        shift || true
        needle="${1:-}"
        if [ -z "$needle" ]; then
            echo "Error: falta tag. Uso: workspace.sh filter-tag <modo> <tag>" >&2
            exit 1
        fi
        plans_dir="$WORKSPACES_DIR/$mode/plans"
        idx="$plans_dir/index.tsv"
        if [ ! -f "$idx" ]; then
            echo "Sin coincidencias."
            exit 0
        fi
        # Pre-filtramos por tag exacto (col 4 nueva; default 'general'
        # para índices viejos) y dejamos las líneas TSV crudas. El
        # formatter común agrega el status del sidecar.
        matches=$(awk -F'\t' -v n="$needle" '
            {
                if (NF >= 6) { t=$4 } else { t="general" }
                if (t == n) print
            }' "$idx")
        if [ -z "$matches" ]; then
            echo "Sin coincidencias."
            exit 0
        fi
        printf '%s\n' "$matches" | format_index_lines "$plans_dir"
        ;;
    filter-priority)
        mode="${1:-}"
        require_mode "$mode"
        shift || true
        needle="${1:-}"
        case "$needle" in
            low|normal|high) ;;
            *)
                echo "Error: priority debe ser low/normal/high. Recibido: '${needle:-}'." >&2
                exit 1
                ;;
        esac
        plans_dir="$WORKSPACES_DIR/$mode/plans"
        idx="$plans_dir/index.tsv"
        if [ ! -f "$idx" ]; then
            echo "Sin coincidencias."
            exit 0
        fi
        # Pre-filtramos por priority (col 5; default 'normal' para
        # índices viejos). Mismo principio que filter-tag.
        matches=$(awk -F'\t' -v n="$needle" '
            {
                if (NF >= 6) { p=$5 } else { p="normal" }
                if (p == n) print
            }' "$idx")
        if [ -z "$matches" ]; then
            echo "Sin coincidencias."
            exit 0
        fi
        printf '%s\n' "$matches" | format_index_lines "$plans_dir"
        ;;
    approve-plan)
        mode="${1:-}"
        require_mode "$mode"
        shift || true
        file="${1:-}"
        require_basename "$file"
        plan_file="$WORKSPACES_DIR/$mode/plans/$file"
        if [ ! -f "$plan_file" ]; then
            echo "Error: plan no encontrado: $plan_file" >&2
            exit 1
        fi
        write_state "$plan_file" "approved" ""
        echo "Plan aprobado: $plan_file"
        ;;
    reject-plan)
        mode="${1:-}"
        require_mode "$mode"
        shift || true
        file="${1:-}"
        require_basename "$file"
        shift || true
        # Razón opcional, multi-word vía $@.
        reason="${*:-}"
        reason="${reason#"${reason%%[![:space:]]*}"}"
        reason="${reason%"${reason##*[![:space:]]}"}"
        plan_file="$WORKSPACES_DIR/$mode/plans/$file"
        if [ ! -f "$plan_file" ]; then
            echo "Error: plan no encontrado: $plan_file" >&2
            exit 1
        fi
        write_state "$plan_file" "rejected" "$reason"
        echo "Plan rechazado: $plan_file"
        [ -n "$reason" ] && echo "Razón: $reason"
        ;;
    plan-status)
        mode="${1:-}"
        require_mode "$mode"
        shift || true
        file="${1:-}"
        require_basename "$file"
        state_file="$WORKSPACES_DIR/$mode/plans/$file.state"
        if [ -f "$state_file" ]; then
            cat "$state_file"
        else
            echo "status=pending"
        fi
        ;;
    executions)
        mode="${1:-}"
        require_mode "$mode"
        exec_dir="$WORKSPACES_DIR/$mode/executions"
        if [ ! -d "$exec_dir" ]; then
            echo "Sin ejecuciones."
            exit 0
        fi
        # Glob *-manifest.md; si no matchea, '[ -f ]' lo descarta.
        found=0
        for f in "$exec_dir"/*-manifest.md; do
            [ -f "$f" ] || continue
            found=1
            echo "$f"
        done
        if [ "$found" -eq 0 ]; then
            echo "Sin ejecuciones."
        fi
        ;;
    last-execution)
        mode="${1:-}"
        require_mode "$mode"
        exec_dir="$WORKSPACES_DIR/$mode/executions"
        if [ ! -d "$exec_dir" ]; then
            echo "Sin ejecuciones."
            exit 0
        fi
        # El último por orden léxico = el más reciente (timestamp YYYYMMDD-HHMMSS).
        last=""
        for f in "$exec_dir"/*-manifest.md; do
            [ -f "$f" ] && last="$f"
        done
        if [ -z "$last" ]; then
            echo "Sin ejecuciones."
            exit 0
        fi
        cat "$last"
        ;;
    show-execution)
        mode="${1:-}"
        require_mode "$mode"
        shift || true
        target="${1:-}"
        if [ -z "$target" ]; then
            echo "Error: falta archivo. Uso: workspace.sh show-execution <modo> <archivo|latest>" >&2
            exit 1
        fi
        exec_dir="$WORKSPACES_DIR/$mode/executions"
        if [ "$target" = "latest" ]; then
            manifest=""
            for f in "$exec_dir"/*-manifest.md; do
                [ -f "$f" ] && manifest="$f"
            done
            if [ -z "$manifest" ]; then
                echo "Error: no hay ejecuciones en $exec_dir." >&2
                exit 1
            fi
        else
            require_basename "$target"
            manifest="$exec_dir/$target"
        fi
        if [ ! -f "$manifest" ]; then
            echo "Error: manifest no encontrado: $manifest" >&2
            exit 1
        fi
        cat "$manifest"
        ;;
    execution-index)
        mode="${1:-}"
        require_mode "$mode"
        idx="$WORKSPACES_DIR/$mode/executions/index.tsv"
        if [ ! -f "$idx" ]; then
            echo "Sin índice de ejecuciones."
            exit 0
        fi
        cat "$idx"
        ;;
    recent-executions)
        mode="${1:-}"
        require_mode "$mode"
        shift || true
        n="${1:-5}"
        if ! [[ "$n" =~ ^[0-9]+$ ]]; then
            echo "Error: n debe ser entero. Recibido: '$n'." >&2
            exit 1
        fi
        idx="$WORKSPACES_DIR/$mode/executions/index.tsv"
        if [ ! -f "$idx" ]; then
            echo "Sin ejecuciones."
            exit 0
        fi
        # Reformat: timestamp | tool | manifest | plan | status
        # (omitimos mode — redundante con la query).
        tail -n "$n" "$idx" | awk -F'\t' '
            { printf "%s | %s | %s | %s | %s\n", $1, $3, $4, $5, $6 }'
        ;;
    search-executions)
        mode="${1:-}"
        require_mode "$mode"
        shift || true
        needle="${*:-}"
        needle="${needle#"${needle%%[![:space:]]*}"}"
        needle="${needle%"${needle##*[![:space:]]}"}"
        if [ -z "$needle" ]; then
            echo "Error: falta texto a buscar. Uso: workspace.sh search-executions <modo> <texto>" >&2
            exit 1
        fi
        idx="$WORKSPACES_DIR/$mode/executions/index.tsv"
        if [ ! -f "$idx" ]; then
            echo "Sin coincidencias."
            exit 0
        fi
        # grep -iF: case-insensitive fixed-string contra la línea
        # completa. Matchea tool / manifest / plan / status (también
        # ts/mode, pero los campos clave del search son los del
        # medio).
        matches=$(grep -iF -- "$needle" "$idx" || true)
        if [ -z "$matches" ]; then
            echo "Sin coincidencias."
            exit 0
        fi
        printf '%s\n' "$matches" | awk -F'\t' '
            { printf "%s | %s | %s | %s | %s\n", $1, $3, $4, $5, $6 }'
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
