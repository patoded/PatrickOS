# OpenClaw Tool Contracts

Contrato base para cualquier herramienta que OpenClaw vaya a tener
permitido ejecutar en el futuro. **Beta-0 no ejecuta ninguna
herramienta**; este documento describe los campos que cualquier
herramienta deberá declarar antes de entrar a la allowlist, y el
shape del registro (`configs/openclaw-tools.yaml`) que el sistema
ya consulta.

Documentos hermanos:

- [`OPENCLAW_BETA0_SPEC.md`](OPENCLAW_BETA0_SPEC.md) — contrato técnico
  ya implementado (gates, policy, audit, plans, approval, execution
  gate).
- [`OPENCLAW_SAFETY_MODEL.md`](OPENCLAW_SAFETY_MODEL.md) — modelo de
  amenazas, controles actuales y próximos.

## Principio central

Ninguna herramienta se ejecuta si no se cumplen, en este orden,
**todas** las precondiciones:

1. **Policy OK** — `openclaw-policy.sh check` exit 0, invariantes
   seguras intactas.
2. **Kill switch inactivo** — `$PATRICK_OS_HOME/openclaw/KILL_SWITCH`
   no existe.
3. **Plan aprobado** — `<plan>.state` contiene `status=approved`
   para el plan que se está intentando ejecutar.
4. **Herramienta en allowlist** — `configs/openclaw-tools.yaml`
   tiene la herramienta declarada con `state: enabled` (en Beta-0
   esta lista es `[]`).
5. **Contrato definido** — la entrada de la herramienta cumple el
   schema mínimo (sección "Contrato mínimo" abajo). Sin contrato
   completo, no se habilita.
6. **Confirmación humana explícita** — el usuario aprobó la corrida
   en una sesión TTY interactiva. Sin TTY no se ejecuta.

Si cualquiera de las seis falla, el resultado es uno de los estados
de la siguiente sección. **En Beta-0 el resultado siempre es
`blocked_beta0`**, sin importar el resto del estado, porque el
runtime de ejecución no existe.

## Estados

Estados terminales que produce o producirá el execution gate. Cada
uno tiene un evento de audit log correspondiente cuando aplica.

- `dry_run` — el plan se generó y guardó; nada se ejecutó. Estado
  natural de cualquier `claw run` permitido en Beta-0.
- `blocked_by_policy` — `openclaw-policy.sh check` falló. Evento
  `run_blocked_policy` / `execute_blocked_policy`.
- `blocked_by_kill_switch` — el archivo `KILL_SWITCH` existe. Evento
  `run_blocked_kill_switch` / `execute_blocked_kill_switch`.
- `blocked_missing_approval` — el plan no tiene sidecar
  `status=approved`. Evento `execute_missing_approval`.
- `blocked_missing_contract` — la herramienta no está en
  `openclaw-tools.yaml`, o su entrada no cumple el schema. En Beta-0
  toda invocación de herramienta cae acá (lista vacía).
- `blocked_beta0` — todos los gates anteriores pasaron y la
  herramienta tiene contrato válido, pero no hay runtime real
  todavía. Evento `execute_blocked_beta0`.

## Contrato mínimo por herramienta

Cada herramienta que se agregue al registro tiene que declarar **todos**
los campos siguientes. Una entrada incompleta es `blocked_missing_contract`.

| Campo | Tipo | Notas |
|---|---|---|
| `name` | string | Identificador único, `[a-z][a-z0-9_]*`. |
| `enabled` | bool | **`false` por contrato en Beta-0/v0.4.** Habilitar requiere PR explícito que actualice safety model + Beta-1 plan. |
| `description` | string | Una línea, qué hace; sirve para el audit. |
| `allowed_modes` | lista de strings | Subset de `consulta, clase, video, desarrollo, ia, general`. Lista vacía = ningún modo (efectivamente disabled). |
| `allowed_args` | lista de patrones | Regex o globs literales contra cada arg recibido. Si vacía: ningún arg permitido. |
| `denied_args` | lista de patrones | Evaluado después de `allowed_args`. Si matchea, se rechaza con un evento de audit. Útil para banear flags peligrosos puntuales (`--system`, `--global`, etc.). |
| `filesystem_scope` | string | Path absoluto donde la herramienta puede leer/escribir. Solo se permite `$PATRICK_OS_HOME/workspaces/<modo>/`, `$PATRICK_OS_HOME/notes/`, `$PATRICK_OS_HOME/todos/` o paths de repo declarados. Cualquier otra ruta requiere PR aparte. |
| `network` | enum: `disabled` (default) o `allowlist:<lista>` | Beta-0 y Beta-1 inicial: siempre `disabled`. Habilitar red por host requiere otro PR con su propia revisión. |
| `sudo` | enum: `disabled` o `false` | **Siempre prohibido `true`/`enabled`.** Cualquier herramienta que necesite root no entra al registro. |
| `timeout_seconds` | entero | Cota dura por invocación; Watson mata el subproceso si vence. Default conservador 30s. |
| `requires_confirmation` | bool | **Siempre `true` en Beta-0/v0.4.** El human gate es no-negociable hasta que existan los controles de Beta-1 fase 5. |
| `log_level` | enum: `minimal`, `verbose`, `audit` | `minimal` registra solo la invocación + exit code; `verbose` agrega stdout/stderr; `audit` registra todo lo necesario para forensia. Default conservador `audit`. |

Una entrada actual del registry (desde v0.4, todas `enabled: false`):

```yaml
tools:
  - name: read_file
    enabled: false
    description: Lee un archivo de texto dentro del workspace del modo activo.
    allowed_modes: [desarrollo]
    allowed_args: ["^[A-Za-z0-9._/-]+$"]
    denied_args: ["^/", "\\.\\."]
    filesystem_scope: "$PATRICK_OS_HOME/workspaces/desarrollo/"
    network: disabled
    sudo: disabled
    timeout_seconds: 5
    requires_confirmation: true
    log_level: audit
```

## Herramientas candidatas (allowlist disabled)

Desde v0.4, **las 7 candidatas están declaradas en
`configs/openclaw-tools.yaml` con `enabled: false`**. Tener el
contrato escrito permite ejercitar `openclaw-contracts.sh check`
con shape real, pero ninguna se ejecuta — el policy gate FALLA si
alguna pasa a `enabled: true`.

- `read_file` — lectura de archivos dentro del workspace de desarrollo.
- `list_dir` — listado dentro del workspace de desarrollo.
- `append_note` — append a `notes/notes.md` (path que Watson ya gestiona).
- `create_task` — append a `todos/todos.md`.
- `git_status` — read-only sobre el repo del usuario.
- `git_diff` — read-only.
- `run_tests` — `make check`. La primera ejecución de proceso "real"
  cuando Beta-1 fase 7 prenda algo. Requiere sandbox a nivel
  proceso (ver safety model).

Candidatas futuras todavía no declaradas (siguen siendo discusión):

- `write_file` — escritura dentro del workspace.
- `git_commit` — la primera escritura `git` con `requires_confirmation: true`.

El orden no es prescriptivo. La primera herramienta habilitada en
Beta-1 será la más conservadora del subset (probablemente
`list_dir` o `read_file`).

## Reglas duras (no negociables)

Cualquier entrada que viole estas reglas se rechaza en review:

- **`sudo` siempre `false`.** OpenClaw nunca escala privilegios.
- **`network: disabled` por default.** Habilitar red requiere PR
  específico, allowlist por host y aprobación humana por sesión.
- **Sin shell libre.** Las herramientas no reciben `sh -c`, `bash
  -c`, ni acceso a un intérprete. Llamadas directas con `argv` o
  nada.
- **Sin `eval`.** Ni en bash, ni en python, ni en ningún path del
  runtime.
- **Sin pipes arbitrarios.** Una invocación = un comando con
  argumentos. Si una herramienta necesita pipe, se declara como
  herramienta compuesta con su propio contrato.
- **Sin redirecciones arbitrarias.** Stdout/stderr van al audit log
  según `log_level`; el código del runtime decide el FD destino,
  no la herramienta.
- **Sin escritura fuera del workspace** salvo herramientas
  explícitamente declaradas con `filesystem_scope` específico (y
  aprobadas por PR). `append_note` / `create_task` son las únicas
  excepciones previstas, y ambas escriben en paths fijos que
  Watson ya gestiona.
- **Todo queda auditado.** Cada llamada genera al menos un evento
  en `audit.log` con `event=tool_*`, `result`, `detail` y el tool
  name. Sin excepciones por "tools rápidas".

## Beta-0 / v0.4

**Ninguna herramienta real se ejecuta.**

`configs/openclaw-tools.yaml` tiene `default_state: disabled` y a
partir de v0.4 contiene **7 candidatas allowlist con
`enabled: false`** (ver [Allowlist spec disabled](#allowlist-spec-disabled)
abajo). `openclaw-policy.sh check` mantiene `tool registry: ningún
tool enabled` mientras eso se cumpla. Si cualquier entrada cambia a
`enabled: true`, el policy gate FALLA — esa puerta se abre recién
con Beta-1 cuando el runtime + los controles del
[modelo de seguridad](OPENCLAW_SAFETY_MODEL.md) estén en código.

El execution gate (`watson claw execute`) sigue siempre en
`blocked-by-design` independientemente del contenido de
`openclaw-tools.yaml`.

### Allowlist spec disabled

Las 7 candidatas de Beta-1 declaradas en `configs/openclaw-tools.yaml`,
todas `enabled: false`:

- `read_file`, `list_dir` — lectura dentro de
  `$PATRICK_OS_HOME/workspaces/desarrollo/`.
- `append_note`, `create_task` — append a `notes/notes.md` /
  `todos/todos.md`.
- `git_status`, `git_diff` — read-only sobre `$HOME/patrick-os/`.
- `run_tests` — `make check` sobre `$HOME/patrick-os/`.

Todas comparten: `network: disabled`, `sudo: disabled`,
`requires_confirmation: true`, `log_level: audit`. Habilitar
cualquiera requiere PR explícito.

## Validación actual

A partir de v0.4 hay un validador dedicado de los contratos del
registry, separado del policy check pero compartiendo el archivo:

```bash
scripts/openclaw-contracts.sh check   # baseline + shape + reglas duras
watson contracts check                # alias: ctr
make contracts-check                  # target del Makefile
```

Adicionalmente desde v0.4 hay **simulación audit-only** de cualquier
candidata del registry, que ejercita el camino de invocación sin
ejecutar binarios:

```bash
scripts/openclaw-simulate-tool.sh <tool> [args...]
watson tool simulate <tool>      # alias de plural
watson tools simulate <tool>
watson simtool <tool>            # sugar
```

La simulación valida que la tool existe en el registry, que su
`enabled` es `false`, y emite el plan `Status: simulated-only`
+ el evento `tool_simulated` en el audit log. Tool inexistente →
exit 1 + `tool_unknown`. Tool con `enabled: true` → exit 1 +
`tool_enabled_forbidden`. **Ningún path ejecuta nada.**

El validador hace tres cosas:

1. Confirma los invariantes baseline (`version: 1`,
   `default_state: disabled`).
2. Si `tools: []`: reporta `[OK] tool registry disabled/empty` y sale 0.
3. Si `tools` no está vacío (caso actual desde v0.4): para cada
   entrada verifica presencia de los **12 campos** del contrato
   (name, **enabled**, description, allowed_modes, allowed_args,
   denied_args, filesystem_scope, network, sudo, timeout_seconds,
   requires_confirmation, log_level), y aplica reglas duras — FAIL
   si alguna tool declara `sudo: true|enabled`, `network: enabled`,
   **`enabled: true`**, **`requires_confirmation: false`**, un
   `name` que no matchea `[a-z][a-z0-9_]*`, o un valor en
   `allowed_modes` fuera del set permitido.

El validador NO interpreta valores YAML completos (sin parser
externo); usa `grep` + `awk` sobre patrones literales. Es suficiente
para el shape chico y predecible del contrato. Cuando el archivo
crezca, hay que reescribirlo.

**El registry actual sigue `disabled/empty` y ningún contrato
habilita ejecución real todavía.** Habilitar la primera herramienta
requiere PR explícito que actualice este documento, el modelo de
seguridad, y `OPENCLAW_BETA1_PLAN.md`.
