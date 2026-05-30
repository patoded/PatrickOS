# OpenClaw Beta-0 — Spec

Estado: **implementado en modo dry-run**. Esta entrega cubre todo el
camino seguro (gates, audit, plan history, approval, execution gate)
sin ejecutar ninguna herramienta real. El runtime de ejecución **sigue
NO implementado** y, por diseño, ningún comando lo dispara en Beta-0.

Aclaraciones explícitas y verificables:

- **`watson claw run`** escribe un plan markdown y nada más. No corre
  herramientas, no llama a binarios externos, no toca red, no escala
  privilegios.
- **`watson ws approve-plan` NO ejecuta nada.** Solo escribe un sidecar
  local `<plan>.state` con `status=approved`. Cambiar de decisión es
  re-aprobar/rechazar; sobrescribe.
- **`watson claw execute` NO ejecuta nada en Beta-0.** Corre la cadena
  completa de gates (kill switch, policy, aprobación). Si todos pasan,
  imprime `Estado: blocked-by-design` y sale en 1. Es el harness para
  cuando Beta-1 conecte un runtime real.

Documentos hermanos:

- [`OPENCLAW_SAFETY_MODEL.md`](OPENCLAW_SAFETY_MODEL.md) — modelo de
  amenazas, controles actuales y los que faltan antes de habilitar
  ejecución real.
- [`OPENCLAW_TOOL_CONTRACTS.md`](OPENCLAW_TOOL_CONTRACTS.md) — contrato
  formal de cualquier herramienta futura + estado del registry.
- [`OPENCLAW_BETA0_CHECKLIST.md`](OPENCLAW_BETA0_CHECKLIST.md) —
  checklist formal de cierre de Beta-0.

## Roles

- **Watson** = identidad del usuario, interfaz CLI y *border guard*.
  Recibe comandos, valida permisos, decide si una operación puede
  delegarse, y traduce la respuesta de OpenClaw en algo presentable.
  Es el único que habla con el usuario.
- **OpenClaw** = motor agéntico futuro. En Beta-0 se materializa como
  `scripts/openclaw-stub.sh`, que genera planes y valida gates. Cuando
  exista runtime real, llega encerrado en el mismo contrato.

OpenClaw nunca habla con el usuario directo. Watson nunca ejecuta
herramientas del motor agéntico fuera del contrato de Beta-0.

## Modos permitidos

`consulta`, `clase`, `video`, `desarrollo`, `ia`, `general`. Cualquier
otro modo se rechaza con exit 1.

## Layout en disco

Todo bajo `$PATRICK_OS_HOME` (default `~/.patrick-os`):

```
~/.patrick-os/
├── openclaw/
│   ├── openclaw.log           legacy log de run permitidos
│   ├── audit.log              bitácora estructurada de eventos
│   └── KILL_SWITCH            (si existe → run/execute bloqueados)
└── workspaces/<modo>/
    ├── README.md              creado por workspace.sh init
    ├── last-plan.md           último plan dry-run
    └── plans/
        ├── <YYYYMMDD-HHMMSS>-plan.md     historial inmutable
        ├── <YYYYMMDD-HHMMSS>-plan.md.state (sidecar opcional)
        └── index.tsv          índice append-only de runs permitidos
```

`configs/openclaw-policy.yaml` define la policy local; vive en el repo
y se copia a `/usr/local/share/patrick-os/configs/` al instalar.

## Cadena de gates

Los gates son la capa de seguridad concreta de Beta-0. Cada uno emite
un evento auditable. Orden de evaluación (primero que dispara gana):

1. **Basename estricto** en cualquier comando que reciba `<filename>`
   (`show-plan`, `approve-plan`, `reject-plan`, `plan-status`,
   `execute`). Si el nombre contiene `/` o `..` → exit 1 antes de
   tocar el FS.
2. **KILL_SWITCH local** (`$PATRICK_OS_HOME/openclaw/KILL_SWITCH`).
   Si el archivo existe, `claw run` y `claw execute` abortan. El
   switch lo crea/borra el usuario con `watson claw kill ["razón"]`
   y `watson claw unkill`. El sidecar contiene `killed_at` y `reason`
   opcional. Eventos: `run_blocked_kill_switch`,
   `execute_blocked_kill_switch`.
3. **Policy gate** (`configs/openclaw-policy.yaml`). `openclaw-policy.sh
   check` valida seis invariantes:
   - `network: disabled`
   - `sudo: disabled`
   - `plugins: disabled`
   - `marketplace: disabled`
   - `tool_whitelist: []`
   - `kill_switch: true`

   Cualquier desviación → FAIL exit 1. Eventos: `run_blocked_policy`,
   `execute_blocked_policy`.
4. **Aprobación local** (solo `execute`). Lee `<plan>.state` y exige
   `status=approved` exacto. Si falta o difiere, imprime hint
   copy-paste con `watson ws approve-plan <modo> <file>`. Evento:
   `execute_missing_approval`.
5. **Blocked-by-design** (`execute` cuando todos los gates pasan).
   Beta-0 no tiene runtime: imprime `Estado: blocked-by-design`, exit
   1. Evento: `execute_blocked_beta0`.

Para `run` además se rechaza:

- Modo no permitido → `run_invalid_mode`, exit 1.
- Tarea vacía → `run_empty_task`, exit 1.

## Plans

### Formato markdown

Cada `claw run` permitido escribe `last-plan.md` y una copia en
`plans/<YYYYMMDD-HHMMSS>-plan.md`. El contenido es markdown
estructurado:

```markdown
# OpenClaw Dry Run Plan

## Metadata
Fecha: YYYY-MM-DD HH:MM:SS
Modo: <modo>
Workspace: <path>
Tag: <tag>
Priority: <low|normal|high>
Policy: OK
Tool whitelist: empty
Kill switch: disabled

## Tarea solicitada
<texto>

## Interpretación
<texto>          # literal: sin LLM en este path

## Plan propuesto
1. Revisar contexto local permitido.
2. Definir pasos seguros.
3. Confirmar antes de cualquier ejecución real futura.

## Herramientas
- Permitidas: ninguna
- Red: deshabilitada
- Sudo: deshabilitado
- Plugins: deshabilitados
- Marketplace: deshabilitado

## Estado
Dry-run. Nada ejecutado.
```

### Metadata: tags y priority

- `--tag <tag>` default `general`. Debe matchear `^[A-Za-z0-9_-]+$`;
  cualquier otro carácter → exit 1.
- `--priority low|normal|high` default `normal`. Fuera del enum → exit 1.

### Índice TSV

`plans/index.tsv` es append-only, una línea por `run_allowed`:

```
timestamp \t mode \t filename \t tag \t priority \t task
```

`task` se sanitiza contra tabs/newlines/CR antes de escribir.

### Sidecar de aprobación

`<plan>.state` (creado por `approve-plan` / `reject-plan`):

```
status=approved|rejected
timestamp=YYYY-MM-DD HH:MM:SS
reason=<texto opcional>
```

Planes sin sidecar se reportan como `status=pending` en los listados.

## Comandos disponibles

### Watson (Beta-0)

```
# Estado y policy
watson claw status
watson policy [show|path|check]   (alias: pol)
watson claw policy

# Kill switch
watson claw kill ["razón"]
watson claw unkill

# Run dry-run
watson claw run [--mode <m>] [--tag <t>] [--priority <p>] "tarea"

# Execution gate (siempre blocked-by-design en Beta-0)
watson claw execute --mode <m> <basename>

# Plans: histórico y visualización
watson ws plans <modo>
watson ws plan-index <modo>
watson ws last-plan <modo>
watson ws show-plan <modo> <archivo|latest>

# Plans: búsqueda y filtrado
watson ws recent <modo> [n]
watson ws search <modo> <texto>
watson ws filter-tag <modo> <tag>
watson ws filter-priority <modo> <low|normal|high>

# Plans: aprobación local
watson ws approve-plan <modo> <basename>
watson ws reject-plan <modo> <basename> [razón]
watson ws plan-status <modo> <basename>

# Audit log
watson audit [list|tail|path|summary]   (alias: aud)

# Tool registry (read-only en Beta-0: siempre vacío/deshabilitado)
watson tools [list|show|path]           (alias: tls)
```

`watson tools` es el viewer del registry definido en
[`OPENCLAW_TOOL_CONTRACTS.md`](OPENCLAW_TOOL_CONTRACTS.md). En Beta-0
`tools list` siempre responde `"No hay herramientas habilitadas."` y
`policy check` exige que `tools=[]` y `default_state=disabled` se
mantengan.

### Eventos auditados

`openclaw-audit.sh summary` lista el catálogo completo con counters:

```
kill, unkill,
run_allowed, run_blocked_kill_switch, run_blocked_policy,
run_invalid_mode, run_empty_task,
execute_blocked_beta0, execute_blocked_kill_switch,
execute_blocked_policy, execute_missing_approval,
status, policy
```

Formato de cada línea de `audit.log`:

```
YYYY-MM-DD HH:MM:SS | event=<evento> | mode=<modo|-> | result=<ok|blocked|fail|info> | detail=<texto>
```

## Diagnóstico

`watson doctor` corre, entre otras secciones, smokes end-to-end de
todo lo anterior:

- `--- openclaw dry-run smoke ---` exige `last-plan.md`, `plans/`
  con ≥1 archivo y `index.tsv` con la metadata tag/priority del run.
- `--- audit smoke ---` exige `audit.log` con eventos y verifica
  que `audit summary` corre.
- Plan viewer (`last-plan` + `show-plan latest`).
- Plan search (`recent` + `search` + `filter-tag` + `filter-priority`).
- Plan approval + execution gate end-to-end:
  pending → execute (missing approval) → approve → approved →
  execute → blocked-by-design.

## Intención original NO implementada en Beta-0

El spec inicial mencionaba estos puntos como contrato futuro. Beta-0
no los necesita (no hay runtime); quedan documentados para Beta-1+:

- **Transporte por socket UNIX o stdin/stdout con framing JSON
  ndjson.** En Beta-0 todo es bash subprocess + archivos en disco.
  Cuando OpenClaw sea un proceso separado con un runtime real, se
  vuelve relevante.
- **Timeout duro por invocación.** No aplica al stub.
- **OpenClaw como subproceso lanzado por Watson.** Hoy es un script
  invocado por Watson; el modelo "proceso separado" es el mismo
  conceptualmente pero sin un runtime distinto.

Cualquier cambio a este contrato (red, sudo, plugins, marketplace,
o transporte) requiere PR explícitamente etiquetado, revisión y
actualización de este documento + del modelo de seguridad.

## Cuándo pasa a Beta-1

Beta-1 (no en v0.3) podrá empezar a habilitar herramientas **una
por una** con whitelist explícita, dentro del mismo contrato de
gates / aislamiento / kill switch que define Beta-0. Antes de
prender la primera herramienta, los controles adicionales del
[modelo de seguridad](OPENCLAW_SAFETY_MODEL.md) tienen que estar
en código.
