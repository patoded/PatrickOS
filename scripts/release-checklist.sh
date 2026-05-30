#!/usr/bin/env bash
# release-checklist.sh — chequeo rápido pre-release.
#
# Uso:
#   scripts/release-checklist.sh              # usa _VERSION de watson.py
#   scripts/release-checklist.sh v0.2.0-alpha # explícito
#
# Reporta OK/TODO/FAIL por ítem. Nunca aborta; el operador decide si
# publica. Distinción:
#   OK    — verificado, todo bien
#   TODO  — pendiente esperable; no bloquea (p.ej. ISO antes del build)
#   FAIL  — algo concreto está roto (p.ej. make check falla)
#
# Exit code = nº de FAILs (TODOs no cuentan).

echo "PatrickOS — Release checklist"
echo

ok_count=0
todo_count=0
fail_count=0

ok()   { echo "[OK]   $1"; ok_count=$((ok_count + 1)); }
todo() { echo "[TODO] $1"; todo_count=$((todo_count + 1)); }
fail() { echo "[FAIL] $1"; fail_count=$((fail_count + 1)); }

# Resolver root del repo. Cuando el script está instalado en
# /usr/local/share/patrick-os/scripts/ el repo no existe localmente; en
# ese caso usamos el cwd y dejamos que los checks fallen como [TODO].
script_dir="$(cd "$(dirname "$0")" && pwd)"
case "$script_dir" in
    /usr/local/share/*) repo_dir="$(pwd)" ;;
    *)                  repo_dir="$(dirname "$script_dir")" ;;
esac

# Versión: arg explícito gana; si no, leemos _VERSION de watson.py.
watson_version=$(grep -E '^_VERSION' "$repo_dir/watson/watson.py" 2>/dev/null \
                    | head -1 | sed 's/.*"\(.*\)".*/\1/')
target_version="${1:-${watson_version:-v0.2.0-alpha}}"

echo "Target: $target_version"
echo

# 1) git status limpio.
if [ -d "$repo_dir/.git" ]; then
    if (cd "$repo_dir" && git diff --quiet && git diff --cached --quiet); then
        ok "git status limpio en $repo_dir"
    else
        todo "git status sucio en $repo_dir (commit o stash antes de tagear)"
    fi
else
    todo "no es un repo git ($repo_dir)"
fi

# 2) Watson reporta la versión esperada. Si se llamó sin arg, esto es
#    una tautología, pero igual lo mostramos para que quede en el log.
#    Caso intermedio: durante el ciclo de desarrollo de un alpha, _VERSION
#    suele ser "vX.Y.Z-dev" mientras el target ya es "vX.Y.Z-alpha". Eso
#    no es una falla — marcamos TODO ("bumpeá _VERSION cuando estés
#    listo a tagear") para que el operador no se trabe.
dev_of() {
    # "v0.3.0-alpha" -> "v0.3.0-dev"
    case "$1" in
        *-alpha) echo "${1%-alpha}-dev" ;;
        *)       echo "" ;;
    esac
}
if [ -n "$watson_version" ]; then
    if [ "$watson_version" = "$target_version" ]; then
        ok "watson version = $watson_version"
    elif [ "$watson_version" = "$(dev_of "$target_version")" ]; then
        todo "watson version = '$watson_version' (ciclo de desarrollo de '$target_version'); bumpeá _VERSION en watson/watson.py al tagear"
    else
        fail "watson version = '$watson_version' (esperado: '$target_version'); actualizar _VERSION en watson/watson.py"
    fi
else
    fail "no se pudo leer _VERSION de $repo_dir/watson/watson.py"
fi

# 3) Release notes para esta versión.
notes="$repo_dir/docs/RELEASE_NOTES_${target_version}.md"
if [ -f "$notes" ]; then
    ok "release notes: $notes"
else
    fail "release notes faltantes: $notes"
fi

# 4) Checklist por familia de versión (v0.2 → V0.2_ALPHA_CHECKLIST.md,
#    v0.3 → V0.3_ALPHA_CHECKLIST.md, etc.). v0.4 todavía no tiene
#    checklist propio — el plan/release notes cubren el estado del
#    ciclo; cuando aparezca, se agrega acá.
case "$target_version" in
    v0.2.*) checklist="$repo_dir/docs/V0.2_ALPHA_CHECKLIST.md" ;;
    v0.3.*) checklist="$repo_dir/docs/V0.3_ALPHA_CHECKLIST.md" ;;
    *)      checklist="" ;;
esac
if [ -n "$checklist" ]; then
    if [ -f "$checklist" ]; then
        ok "checklist: $checklist"
    else
        fail "checklist faltante: $checklist"
    fi
fi

# 5) Contexto operativo.
ctx="$repo_dir/docs/PROJECT_CONTEXT.md"
if [ -f "$ctx" ]; then
    ok "contexto operativo: $ctx"
else
    fail "contexto faltante: $ctx"
fi

# 5b) Docs de OpenClaw obligatorios por familia de versión. La
#    presencia de estos archivos materializa el contrato del ciclo.
#    v0.3 cerró Beta-0; v0.4 mantiene esos + suma los de Beta-1
#    planning (plan, negative tests).
case "$target_version" in
    v0.3.*)
        for f in OPENCLAW_BETA0_SPEC.md \
                 OPENCLAW_SAFETY_MODEL.md \
                 OPENCLAW_TOOL_CONTRACTS.md \
                 OPENCLAW_BETA0_CHECKLIST.md; do
            if [ -f "$repo_dir/docs/$f" ]; then
                ok "doc OpenClaw: docs/$f"
            else
                fail "doc OpenClaw faltante: docs/$f"
            fi
        done
        ;;
    v0.4.*)
        # Beta-0 docs siguen siendo contrato vivo en v0.4 (el dry-run
        # no se desarma); a eso le sumamos los docs nuevos del ciclo
        # de Beta-1 planning.
        for f in OPENCLAW_BETA0_SPEC.md \
                 OPENCLAW_SAFETY_MODEL.md \
                 OPENCLAW_TOOL_CONTRACTS.md \
                 OPENCLAW_BETA0_CHECKLIST.md \
                 V0.4_PLAN.md \
                 OPENCLAW_BETA1_PLAN.md \
                 OPENCLAW_NEGATIVE_TESTS.md; do
            if [ -f "$repo_dir/docs/$f" ]; then
                ok "doc OpenClaw: docs/$f"
            else
                fail "doc OpenClaw faltante: docs/$f"
            fi
        done
        # Scripts nuevos del safety foundation (Beta-1 prerequisites).
        # No se exigen +x acá — eso lo destapa check-installed.
        for s in openclaw-contracts.sh openclaw-negative-tests.sh; do
            if [ -f "$repo_dir/scripts/$s" ]; then
                ok "script OpenClaw v0.4: scripts/$s"
            else
                fail "script OpenClaw v0.4 faltante: scripts/$s"
            fi
        done
        # Recordatorio operativo (no es un check, solo hint).
        todo "validación obligatoria sugerida antes de tagear: make safety-check"
        ;;
esac

# 6) make check pasa. Lo corremos en modo silencioso; si truena, marcamos
#    FAIL para que el operador no publique con tests rotos. Si no hay
#    make/Makefile, lo dejamos como TODO (entorno mínimo).
if command -v make >/dev/null 2>&1 && [ -f "$repo_dir/Makefile" ]; then
    if (cd "$repo_dir" && make check >/dev/null 2>&1); then
        ok "make check pasa"
    else
        fail "make check falla (corré 'make check' para ver el detalle)"
    fi
else
    todo "make/Makefile no disponible; saltando 'make check'"
fi

# 7) ISO de la versión target. NO es obligatoria todavía en v0.2.0-alpha
#    (esta release prepara metadata/docs; el build se hace en un PR
#    posterior). Solo cuenta el path versionado: ISOs de releases
#    previas (p.ej. patrick-os-alpha.iso de v0.1) NO satisfacen este
#    check porque no representan el target actual. Falta = TODO, no FAIL.
iso="$repo_dir/iso/patrick-os-${target_version}.iso"
if [ -f "$iso" ]; then
    ok "ISO presente: $iso ($(du -h "$iso" 2>/dev/null | cut -f1))"
else
    todo "ISO faltante: $iso (build queda fuera de este PR; correr build cuando se decida tagear)"
fi

# 8) SHA256 de la ISO (solo si la ISO de target existe).
sha="$iso.sha256"
if [ -f "$iso" ]; then
    if [ -f "$sha" ]; then
        ok "SHA256 presente: $sha"
    else
        todo "SHA256 faltante (sha256sum \"$iso\" > \"$sha\")"
    fi
fi

# 9) Git tag opcional. Si todavía no se tagueó, lo marcamos como TODO
#    (el tag se crea cuando el operador decide publicar).
if [ -d "$repo_dir/.git" ]; then
    if (cd "$repo_dir" && git rev-parse "$target_version" >/dev/null 2>&1); then
        ok "git tag presente: $target_version"
    else
        todo "git tag faltante: $target_version (git -C \"$repo_dir\" tag $target_version cuando estés listo)"
    fi
fi

echo
echo "Resumen: OK=$ok_count TODO=$todo_count FAIL=$fail_count"
if [ "$fail_count" -gt 0 ]; then
    echo "Hay FAILs: resolver antes de publicar."
elif [ "$todo_count" -gt 0 ]; then
    echo "Sin FAILs. Quedan TODOs (no bloqueantes) para cuando decidas publicar."
else
    echo "Listo para publicar."
fi
exit "$fail_count"
