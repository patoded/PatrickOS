# PatrickOS v0.3.0-alpha

## Enfoque

Preparar Watson para operación agéntica segura con OpenClaw Beta-0,
manteniendo ejecución local controlada.

## En desarrollo

- OpenClaw Beta-0 dry-run.
- Workspaces locales.
- Watson doctor.
- Doctor repair.
- Instalación global validada.
- Base para futuros comandos agénticos seguros.

## OpenClaw Beta-0

Capa dry-run segura, sin runtime real. Lo que entra:

- **Dry-run seguro.** `watson claw run` genera plan markdown
  estructurado sin ejecutar nada.
- **Policy layer** (`configs/openclaw-policy.yaml`). Seis invariantes
  validadas en cada `run` y `execute`: `network/sudo/plugins/
  marketplace: disabled`, `tool_whitelist: []`, `kill_switch: true`.
- **Kill switch local** vía archivo (`~/.patrick-os/openclaw/KILL_SWITCH`).
  Pausa táctica que gana sobre policy y todo.
- **Audit log estructurado** (`audit.log`) con catálogo fijo de 13
  eventos + `audit summary` que muestra contadores.
- **Workspaces locales** por modo (`workspace.sh` + sandbox lógico
  en `~/.patrick-os/workspaces/<modo>/`).
- **Plan history** + **plan index** (`plans/index.tsv`) +
  **search/recent/filter-tag/filter-priority** + **tags/priority**
  validadas (`^[A-Za-z0-9_-]+$` y `low|normal|high`).
- **Approval state local** vía sidecar `<plan>.state` con
  `status=approved|rejected`. Aprobar NO ejecuta nada.
- **Execution gate `blocked-by-design`.** `watson claw execute`
  corre la cadena completa de gates y, si todos pasan, termina con
  `Estado: blocked-by-design` y exit 1. NO ejecuta herramientas.
- **Tool contracts** definidos (`docs/OPENCLAW_TOOL_CONTRACTS.md`)
  y **registry vacío** (`configs/openclaw-tools.yaml` con
  `tools: []`, `default_state: disabled`). Viewer en `watson tools
  list/show/path`. Habilitar herramientas requiere PR explícito.
- **Doctor smoke end-to-end** de cada gate (`watson doctor`).
- **Beta-0 checklist formal** en `docs/OPENCLAW_BETA0_CHECKLIST.md`,
  modelo de seguridad en `docs/OPENCLAW_SAFETY_MODEL.md`.

## No incluido todavía

- OpenClaw runtime con ejecución real.
- Red.
- sudo desde agentes.
- plugins externos.
- marketplace.
- NVIDIA propietario.
- Firefox / LibreOffice / OBS.
- ISO v0.3.0-alpha.
