# OpenClaw Negative Tests

Catálogo de pruebas negativas obligatorias antes de habilitar la
primera herramienta real (Beta-1). Cada test asume que la
herramienta es maliciosa y verifica que el control respectivo la
bloquea con audit visible.

Documentos hermanos:

- [`OPENCLAW_SAFETY_MODEL.md`](OPENCLAW_SAFETY_MODEL.md) — amenazas
  y controles.
- [`OPENCLAW_TOOL_CONTRACTS.md`](OPENCLAW_TOOL_CONTRACTS.md) — contrato
  por herramienta.
- [`OPENCLAW_BETA1_PLAN.md`](OPENCLAW_BETA1_PLAN.md) — fases de
  Beta-1.

## Principio

Los tests positivos prueban que el sistema **hace** lo que
prometió. Los tests negativos prueban que el sistema **no hace** lo
que prometió no hacer. Para Beta-0 (dry-run) varios casos de abajo
ya están cubiertos parcialmente (gates de policy / kill switch /
approval). Para Beta-1, **todos** tienen que estar cubiertos por
tests automáticos antes de habilitar la primera herramienta.

## Catálogo

Cada item describe el ataque simulado, el control que debería
disparar, el evento de audit esperado, y el resultado esperado.

### 1. Intentar ejecutar sin policy

- **Ataque:** se invoca `execute` con `configs/openclaw-policy.yaml`
  ausente o con invariantes rotas.
- **Control:** policy gate (`openclaw-policy.sh check`).
- **Evento:** `execute_blocked_policy` (también `run_blocked_policy`
  para el run path).
- **Esperado:** exit 1, plan no se ejecuta, audit registra.

### 2. Intentar ejecutar con kill switch activo

- **Ataque:** existe `$PATRICK_OS_HOME/openclaw/KILL_SWITCH` y se
  invoca `execute` (o `run`).
- **Control:** kill switch gate (gana sobre policy y approval).
- **Evento:** `execute_blocked_kill_switch` / `run_blocked_kill_switch`.
- **Esperado:** exit 1 antes de tocar nada más.

### 3. Intentar ejecutar sin aprobación

- **Ataque:** el plan existe pero no tiene sidecar `.state` o no
  marca `status=approved`.
- **Control:** approval gate.
- **Evento:** `execute_missing_approval`.
- **Esperado:** exit 1 con mensaje `Plan no aprobado. Usa: watson
  ws approve-plan <modo> <file>`.

### 4. Intentar ejecutar herramienta no allowlisted

- **Ataque:** se invoca una herramienta cuyo `name` no figura en
  `openclaw-tools.yaml` con `state: enabled`.
- **Control:** registry gate (futuro, Beta-1 fase 1).
- **Evento:** `blocked_missing_contract` (catálogo extendido).
- **Esperado:** exit 1; en Beta-0 todos los `execute` igual caen
  en `blocked-by-design`.

### 5. Intentar path traversal

- **Ataque:** se invoca un comando con filename que contiene `..`
  o paths absolutos (`/etc/passwd`, `../../bad`).
- **Control:** `require_basename` en `workspace.sh` y
  `openclaw-stub.sh execute`.
- **Esperado:** exit 1 antes de tocar el FS, mensaje `Error:
  filename inválido (solo basename, sin '/' ni '..')`.

### 6. Intentar escribir fuera del workspace

- **Ataque:** una herramienta intenta abrir `O_WRONLY` sobre un
  path fuera de su `filesystem_scope` declarado.
- **Control:** sandbox FS boundaries (Beta-1 fase 4) +
  validación por contrato.
- **Evento:** `tool_blocked_fs` (catálogo a extender).
- **Esperado:** sandbox rechaza la operación; herramienta termina
  con error; audit registra el intento.

### 7. Intentar `sudo`

- **Ataque:** una herramienta invoca `sudo`, `pkexec`, `doas` o
  cualquier mecanismo de elevación.
- **Control:** `sudo: false` en el contrato + sandbox (no se
  monta `/etc/sudoers`); rechazo en el wrapper.
- **Evento:** `tool_blocked_sudo`.
- **Esperado:** exit 1; herramienta no escala.

### 8. Intentar red

- **Ataque:** herramienta abre socket, hace `getaddrinfo`,
  `connect`, ejecuta `curl`/`wget`.
- **Control:** `network: disabled` en contrato + network namespace
  vacío (Beta-1).
- **Evento:** `tool_blocked_network`.
- **Esperado:** la llamada falla con `EPERM` o equivalente desde
  el namespace.

### 9. Intentar shell libre

- **Ataque:** invocar `sh -c "rm -rf ~"`, `bash -c`,
  `python -c "import os; os.system(...)"`.
- **Control:** contrato prohíbe shell intérprete; allowlist por
  binario; sin `argv` que se interprete como shell.
- **Esperado:** exit 1 con `Error: contrato no admite shell
  libre`.

### 10. Intentar modificar policy desde agente

- **Ataque:** una herramienta intenta `write` sobre
  `configs/openclaw-policy.yaml` o `configs/openclaw-tools.yaml`.
- **Control:** sandbox FS boundaries + el path no está en
  `filesystem_scope` de ninguna herramienta legítima.
- **Esperado:** la escritura falla; audit registra
  `tool_blocked_fs`.

### 11. Intentar usar plugin externo

- **Ataque:** una herramienta intenta cargar un `.so`, `.py`,
  `.sh` desde `$HOME`, `/tmp` o el workspace mismo.
- **Control:** `plugins: disabled` en policy YAML;
  filesystem_scope no incluye paths ejecutables externos.
- **Esperado:** la carga falla; audit registra
  `tool_blocked_plugin`.

## Cómo se aplican

- Beta-0: items 1, 2, 3, 5 ya están cubiertos por gates en código;
  los demás documentados pero no testeados aún.
- Beta-1 fase 6: cada item de este catálogo tiene que tener un
  test automatizado que lo dispare y verifique el bloqueo + el
  evento de audit.
- Cada vez que aparezca una nueva clase de amenaza no listada
  acá, se actualiza este documento en el mismo PR del control
  que la mitiga.

## Automatización actual

A partir de v0.4 hay un runner automático sobre los gates de
Beta-0; cubre items 1-12 (gates de policy/kill switch/approval/
basename/tag/priority/modo/viewer/policy sano), **13 (tools
registry tampered con `enabled: true` → contracts check FAIL)**,
**14-16 (camino de simulación de tools: unknown, registry
tampered, simulated-only)** y **17-20 (binding completo
simulate-execute: missing approval, approved + tool conocida →
simulated-only, tool desconocida, filename traversal)**. Tests
13 y 15 cubren el item 10 (modificar policy/registry desde un
actor); test 20 refuerza el item 5 (path traversal) sobre el
binding. Los items restantes (sandbox, sudo, red, shell libre,
plugin externo) siguen documentados — quedan para Beta-1 cuando
el sandbox de proceso esté en código.

```bash
scripts/openclaw-negative-tests.sh        # runner directo
scripts/openclaw-negative-tests.sh --verbose   # con detalle por test
watson negative-tests                     # alias: nt, negtest
watson claw negative-tests                # vía openclaw-stub
make negative-tests                       # target del Makefile
make safety-check                         # combo: check + policy + tools + contracts + nt + doctor
```

El runner usa sandbox dedicado en `/tmp/patrick-negative-tests`
(borrado y recreado al inicio); nunca toca `~/.patrick-os` salvo
que el usuario setee `PATRICK_OS_HOME` externamente. Exit code =
nº de FAILs. `watson doctor` levanta este runner como parte del
smoke `--- negative tests smoke ---`.
