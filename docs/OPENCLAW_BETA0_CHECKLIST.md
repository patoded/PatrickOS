# OpenClaw Beta-0 Checklist

Checklist formal de cierre para OpenClaw Beta-0. Si todas las
secciones pasan en una máquina, Beta-0 puede considerarse cerrada
en esa instalación. Cerrar Beta-0 **no** significa habilitar
ejecución real: significa que la capa dry-run + gates + auditoría
queda fijada como contrato estable, y los próximos pasos hacia
Beta-1 se hacen contra ese contrato.

Documentos hermanos:

- [`OPENCLAW_BETA0_SPEC.md`](OPENCLAW_BETA0_SPEC.md) — contrato técnico.
- [`OPENCLAW_SAFETY_MODEL.md`](OPENCLAW_SAFETY_MODEL.md) — amenazas + controles + límites.
- [`OPENCLAW_TOOL_CONTRACTS.md`](OPENCLAW_TOOL_CONTRACTS.md) — contrato para herramientas futuras.

## Estado

- **Runtime real:** NO implementado.
- **Ejecución real:** NO habilitada.
- **Estado actual:** dry-run seguro.

## Seguridad implementada

Cada item mapea a código y a tests del doctor. Si alguno no está
presente, Beta-0 no está cerrada todavía.

- policy layer (`configs/openclaw-policy.yaml` + `openclaw-policy.sh check`)
- tool registry vacío/deshabilitado (`configs/openclaw-tools.yaml` con `tools: []` / `default_state: disabled`)
- tool contracts documentados (`docs/OPENCLAW_TOOL_CONTRACTS.md`)
- kill switch (`$PATRICK_OS_HOME/openclaw/KILL_SWITCH`)
- audit log estructurado (`$PATRICK_OS_HOME/openclaw/audit.log`)
- audit summary con catálogo fijo de 13 eventos (`openclaw-audit.sh summary`)
- workspaces locales por modo (`scripts/workspace.sh`)
- plan estructurado en markdown (6 secciones)
- plan history en `<workspace>/plans/`
- plan index TSV en `<workspace>/plans/index.tsv`
- viewer de planes (`last-plan`, `show-plan latest|<basename>`)
- búsqueda y filtros (`recent`, `search`, `filter-tag`, `filter-priority`)
- metadata `tags` y `priority` validada en cada run
- approval state (`<plan>.state` con `status=approved|rejected`)
- execution gate `blocked-by-design` (`watson claw execute`)
- doctor smoke end-to-end de cada gate

## Validación obligatoria

Estos comandos deben terminar sin errores antes de declarar Beta-0
cerrada. Ningún paso requiere sudo ni red.

```bash
make check
make check-installed
watson doctor
watson policy check
watson tools list
watson claw status
watson claw run --mode desarrollo --tag doctor --priority high "beta0 checklist smoke"
watson audit summary
```

Lecturas esperadas:

- `make check` → `fails=0`.
- `make check-installed` → `Resultado: OK. Instalación global en sync con el repo.`
- `watson doctor` → `Resumen: OK=10 WARN=… FAIL=0`.
- `watson policy check` → `Resultado: OK. Todas las invariantes seguras se mantienen.`, incluyendo `[OK] tool registry: disabled/empty`.
- `watson tools list` → `No hay herramientas habilitadas.`
- `watson claw status` → `KILL_SWITCH: inactivo` (salvo pausa explícita).
- `watson claw run …` → genera plan, exit 0.
- `watson audit summary` → counters de `execute_blocked_beta0` y compañía visibles.

## Condiciones para NO avanzar a ejecución real

Beta-1 (primera herramienta habilitada) **no** se abre hasta que
**todos** estos controles estén en código y testeados. Si falta
cualquiera, queda bloqueada por diseño.

- Sandbox real a nivel proceso (bwrap / firejail / equivalente).
- Allowlist de comandos concreta, con binarios identificados por
  ruta absoluta.
- Confirmación humana obligatoria por step ejecutado.
- Filesystem boundaries: bind-mounts read-only fuera del workspace,
  sin acceso a `$HOME` ni a `/etc` ni a `/tmp` global.
- Negative tests: suite que asuma herramienta maliciosa y verifique
  que cada control bloquea.
- Logs confiables append-only (más allá de la convención actual).
- Política de rollback documentada o, como mínimo, trazabilidad
  clara: `audit.log` + plan history + sidecar `.state` permiten
  reconstruir qué se intentó.

Detalle en [`OPENCLAW_SAFETY_MODEL.md`](OPENCLAW_SAFETY_MODEL.md)
sección "Próximos controles".

## Decisión

Beta-0 puede considerarse cerrada solo si:

- `watson doctor` → `FAIL=0`.
- `watson policy check` → OK en las 6 invariantes principales + tool registry.
- `watson tools list` confirma vacío/deshabilitado.
- `watson claw execute --mode <m> <plan-aprobado>` termina con
  `Estado: blocked-by-design`.

Si los cuatro pasan, el comentario en el PR de release debe
referenciar este checklist y el hash del commit.
