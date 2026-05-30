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
| `description` | string | Una línea, qué hace; sirve para el audit. |
| `allowed_modes` | lista de strings | Subset de `consulta, clase, video, desarrollo, ia, general`. Lista vacía = ningún modo (efectivamente disabled). |
| `allowed_args` | lista de patrones | Regex o globs literales contra cada arg recibido. Si vacía: ningún arg permitido. |
| `denied_args` | lista de patrones | Evaluado después de `allowed_args`. Si matchea, se rechaza con un evento de audit. Útil para banear flags peligrosos puntuales (`--system`, `--global`, etc.). |
| `filesystem_scope` | string | Path absoluto donde la herramienta puede leer/escribir. Solo se permite `$PATRICK_OS_HOME/workspaces/<modo>/`. Cualquier otra ruta requiere PR aparte. |
| `network` | enum: `disabled` (default) o `allowlist:<lista>` | Beta-0 y Beta-1 inicial: siempre `disabled`. Habilitar red por host requiere otro PR con su propia revisión. |
| `sudo` | bool | **Siempre `false`.** Cualquier herramienta que necesite root no entra al registro. |
| `timeout_seconds` | entero | Cota dura por invocación; Watson mata el subproceso si vence. Default conservador 30s. |
| `requires_confirmation` | bool | `true` siempre para herramientas que escriben o que tocan estado fuera del workspace. `false` solo para reads triviales pre-aprobados en el plan. Beta-0 ignora este campo (todo está bloqueado). |
| `log_level` | enum: `minimal`, `verbose` | `minimal` registra solo la invocación + exit code; `verbose` agrega stdout/stderr. Default `minimal`. |

Una entrada típica futura se vería así (pseudo-YAML, **NO está en
el registro hoy**):

```yaml
tools:
  - name: read_file
    description: Lee un archivo de texto dentro del workspace del modo.
    allowed_modes: [desarrollo]
    allowed_args:
      - "^[A-Za-z0-9._/-]+$"
    denied_args:
      - "^/"        # paths absolutos
      - "\\.\\."   # parent traversal
    filesystem_scope: "$PATRICK_OS_HOME/workspaces/desarrollo/"
    network: disabled
    sudo: false
    timeout_seconds: 5
    requires_confirmation: false
    log_level: minimal
```

## Herramientas candidatas futuras

Lista de discusión, **no habilitada**. Cada nombre es un PR
potencial; ninguno está en `openclaw-tools.yaml` hoy.

- `read_file` — lectura de archivos dentro del workspace.
- `write_file` — escritura dentro del workspace.
- `list_dir` — listado de un dir dentro del workspace.
- `append_note` — append a `notes/notes.md` (el path único que
  Watson hoy ya gestiona).
- `create_task` — append a `todos/todos.md`.
- `git_status` — solo lectura, sobre el repo del usuario.
- `git_diff` — solo lectura.
- `git_commit` — la primera escritura `git`. Requiere
  `requires_confirmation: true` y un PR de seguridad propio.
- `run_tests` — la primera ejecución de proceso "real". Requiere
  sandbox a nivel proceso (ver safety model).

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

## Beta-0

**En Beta-0 ninguna herramienta real se ejecuta.**

`configs/openclaw-tools.yaml` existe con `tools: []` y
`default_state: disabled`. `openclaw-policy.sh check` verifica que
ambos invariantes se mantienen y, si tools.yaml está presente y es
seguro, agrega una línea `[OK] tool registry: disabled/empty` al
reporte. Si el archivo es modificado para incluir herramientas, el
check FALLA — no porque la entrada sea inválida, sino porque
Beta-0 no acepta `tools` con elementos. Esa puerta se abre recién
con Beta-1 cuando el runtime + los controles del
[modelo de seguridad](OPENCLAW_SAFETY_MODEL.md) estén en código.

El execution gate (`watson claw execute`) sigue siempre en
`blocked-by-design` independientemente del contenido de
`openclaw-tools.yaml`.
