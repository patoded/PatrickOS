# OpenClaw Beta-1 Plan

Estado: **propuesta + safety foundation v0.4 en curso**. Beta-1
todavía no está en código y este documento es el plan de cómo
llegar. **OpenClaw runtime real sigue NO implementado.** Nada de
lo descrito acá se prende sin que cada fase pase por su propio PR.

v0.4 abre con la **safety foundation**: validador de contratos
(`scripts/openclaw-contracts.sh`), runner de pruebas negativas
(`scripts/openclaw-negative-tests.sh`), target `make safety-check`
y smokes nuevos en `watson doctor` (`contracts smoke` + `negative
tests smoke`). Ambos son prerequisitos antes de habilitar la
primera herramienta real: no se evalúa ninguna fase de runtime sin
que el contracts validator pase y la suite negativa termine en
FAIL=0.

A partir de v0.4, **las 7 candidatas de Beta-1 ya están declaradas
en `configs/openclaw-tools.yaml`** con `enabled: false`. Esto
cumple la **fase 2** (allowlist concreta) sin habilitar nada: el
shape del contrato vive en código, el validador lo prueba en cada
`make safety-check`, y cualquier intento de pasar una candidata a
`enabled: true` rompe el policy gate antes de cualquier `claw run`.

El **gate de readiness** (`scripts/openclaw-readiness.sh`,
`watson readiness` / `watson beta1` / `watson claw readiness`,
`make readiness`) cubre la evaluación explícita de avance: corre
policy + contracts + tools + negative tests + doctor + execute
gate + simulated binding en cadena, marca `[BLOCKED] real
execution runtime not implemented` como invariante esperada, y
reporta `ready_for_simulated_beta1=yes` mientras todos los OK
pasen. Exit 1 si cualquier OK requerido falla; exit 0 cuando el
estado terminal es "listo para simulación, no para ejecución
real". El doctor smoke nuevo `--- readiness smoke ---` lo
ejecuta y verifica ese estado terminal en cada `make doctor`.

A partir del PR de manifests, cada `simulate-execute` aprobado
escribe un **manifest inmutable** en
`<workspace>/executions/<ts>-<tool>-manifest.md` con metadata,
gates, plan reference, snapshot del contrato y la sección
`Result` que documenta literalmente que nada se ejecutó. Watson
los lee con `ws executions / last-execution / show-execution`.
A partir del PR de index, también appendea una línea TSV a
`<workspace>/executions/index.tsv` con `timestamp / mode / tool
/ manifest / plan / status`, para listado y búsqueda sin abrir
los `.md` uno por uno (`ws execution-index / recent-executions /
search-executions`). Cumple parte de la fase 7 (simulated
execution): cada intento queda con registro auditable + sidecar
legible por humanos + índice escaneable.

A esto se suma **simulated execution** (fase 7), también sin
habilitar nada: `scripts/openclaw-simulate-tool.sh` y los comandos
`watson tool simulate <name>` / `watson simtool <name>` ejercitan
el camino de invocación de una tool — validan el registry, exigen
`enabled: false`, auditan el intento — pero NO ejecutan ningún
binario. Eventos auditados nuevos: `tool_simulated`,
`tool_unknown`, `tool_enabled_forbidden`. **El binding completo
plan → approval → tool simulada** también está en código vía
`watson claw simulate-execute --mode <m> --tool <t> <file>`:
corre la cadena entera de gates (kill switch, policy, plan
exists, approval, tool registry) y termina en
`Status: simulated-only` con `simulate_execute_allowed` en el
audit. Cualquier gate fallido emite su evento específico
(`simulate_execute_missing_approval`,
`simulate_execute_unknown_tool`,
`simulate_execute_blocked_kill_switch`,
`simulate_execute_blocked_policy`) y aborta. Habilitar la
primera entrada sigue requiriendo PR explícito que ataque las
fases 3-6 y 8.

Documentos hermanos:

- [`OPENCLAW_BETA0_SPEC.md`](OPENCLAW_BETA0_SPEC.md) — contrato de la
  capa dry-run actual.
- [`OPENCLAW_TOOL_CONTRACTS.md`](OPENCLAW_TOOL_CONTRACTS.md) — contrato
  por herramienta.
- [`OPENCLAW_SAFETY_MODEL.md`](OPENCLAW_SAFETY_MODEL.md) — amenazas y
  controles.
- [`OPENCLAW_NEGATIVE_TESTS.md`](OPENCLAW_NEGATIVE_TESTS.md) — pruebas
  negativas obligatorias.

## Objetivo

Pasar de **dry-run seguro** (Beta-0) a **preparación de ejecución
controlada** (Beta-1) sin ejecutar todavía. El execution gate sigue
bloqueando en cada fase; lo que cambia es qué tan cerca del runtime
real está la simulación, y qué controles efectivos ya existen
cuando se prenda la primera herramienta.

## Fases

Cada fase es un PR potencial (o un conjunto chico de PRs). Ninguna
fase prende ejecución real por sí sola. Solo después de aprobar
**todas** se evalúa habilitar la primera herramienta.

1. **Tool contracts accionables.** Validador efectivo del schema
   declarado en `OPENCLAW_TOOL_CONTRACTS.md`: un entry en
   `openclaw-tools.yaml` se valida campo por campo antes de aceptar
   `enabled`.
2. **Allowlist concreta.** Primer subset de herramientas candidatas
   declarado en `openclaw-tools.yaml` con `state: disabled` por
   entrada. Permite ejercitar el validador sin habilitar nada.
3. **Sandbox de proceso.** Diseño documentado y prototipo del
   wrapper (`bwrap` / `firejail` / equivalente disponible en la
   ISO) que envolverá cada herramienta. Sin runtime real todavía.
4. **Filesystem boundaries.** Bind-mounts read-only fuera del
   workspace; sin acceso a `$HOME` (fuera de `.patrick-os/`),
   `/etc`, `/tmp` global. Implementado en el wrapper de sandbox.
5. **Human confirmation gate.** Confirmación obligatoria por step
   ejecutado, no por sesión, no global. Sin TTY → no ejecuta.
6. **Negative tests.** Suite que ejerce los casos de
   `OPENCLAW_NEGATIVE_TESTS.md` y asume herramienta maliciosa.
   Cada test verifica que el control respectivo bloquea.
7. **Simulated execution.** Extender el `blocked-by-design` con un
   "would run" detallado: registrar qué comando se hubiera
   ejecutado, con qué args, en qué workspace, bajo qué sandbox.
   Plan + audit reciben este detalle. Sigue sin ejecutar.
8. **Revisión antes de runtime real.** PR final que evalúa,
   contra el modelo de seguridad, si **prender la primera
   herramienta** es seguro. Requiere visto bueno explícito (no
   silencioso) y cierre del checklist de Beta-1 (a redactarse
   cuando llegue ese momento).

## Herramientas candidatas para Beta-1

Solo candidatas. **NO habilitadas.** El orden no es prescriptivo;
la primera en prenderse será la más conservadora del subset
(probablemente `list_dir` o `read_file`).

- `read_file` — lectura de archivos dentro del workspace.
- `list_dir` — listado de un dir dentro del workspace.
- `append_note` — append a `notes/notes.md` que Watson ya gestiona.
- `create_task` — append a `todos/todos.md` que Watson ya gestiona.
- `git_status` — solo lectura sobre el repo del usuario.
- `git_diff` — solo lectura.
- `run_tests` — primera ejecución de proceso "real"; requiere
  sandbox completo + confirmation gate por step + PR específico.

Cada candidata entra al registry recién cuando su contrato completo
está revisado contra `OPENCLAW_TOOL_CONTRACTS.md`.

## Reglas duras

No negociables, valen para todo Beta-1 y siguientes:

- **No shell libre.** Las herramientas no reciben `sh -c`, `bash
  -c`, ni acceso a un intérprete.
- **No `eval`.** Ni en bash, ni en python, ni en ningún path del
  runtime.
- **No pipes arbitrarios.** Una invocación = un comando con
  argumentos. Si hace falta pipe, se declara como herramienta
  compuesta con su propio contrato.
- **No redirecciones arbitrarias.** Stdout/stderr van al audit log
  según `log_level` declarado; la herramienta no decide.
- **No `sudo`.** Cualquier herramienta que necesite root no entra
  al registry.
- **No red por default.** Habilitar red requiere PR específico,
  allowlist por host y aprobación humana por sesión.
- **No acceso fuera del workspace** sin contrato explícito.
  `append_note` / `create_task` son las únicas excepciones
  previstas, y escriben en paths fijos.
- **Todo auditado.** Cada llamada genera al menos un evento
  `tool_*` con `result`, `detail` y el tool name.

## Decisión importante

**Beta-1 NO significa ejecución libre.** Beta-1 significa empezar a
probar herramientas controladas bajo contrato. Cada paso entre
Beta-0 (dry-run) y "primera herramienta real ejecutada" es una
fase chequeable; no hay un único salto.

Si en cualquier fase aparece una clase de amenaza que el modelo de
seguridad no cubre, se actualiza primero
[`OPENCLAW_SAFETY_MODEL.md`](OPENCLAW_SAFETY_MODEL.md) y este
documento, y recién después se vuelve a evaluar avanzar.
