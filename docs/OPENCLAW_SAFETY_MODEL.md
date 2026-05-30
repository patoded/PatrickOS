# OpenClaw — Safety Model

Documento explícito de qué intentamos prevenir, qué controles ya están
en código (Beta-0), qué límites concretos tiene el diseño actual, y qué
controles adicionales son condición necesaria antes de habilitar
ejecución real de herramientas.

Es el documento que hay que actualizar (y revisar) cuando cambie
cualquiera de: la policy YAML, el catálogo de eventos de audit, la
cadena de gates, o cuando se proponga la primera herramienta para
Beta-1.

Documentos hermanos:

- [`OPENCLAW_BETA0_SPEC.md`](OPENCLAW_BETA0_SPEC.md) — contrato técnico
  ya implementado.
- [`OPENCLAW_TOOL_CONTRACTS.md`](OPENCLAW_TOOL_CONTRACTS.md) — contrato
  formal por herramienta.
- [`OPENCLAW_BETA0_CHECKLIST.md`](OPENCLAW_BETA0_CHECKLIST.md) —
  checklist formal de cierre de Beta-0.

Beta-0 ya tiene su checklist de cierre. Desde v0.4, el tool
registry ya **tiene la allowlist concreta** (`configs/openclaw-tools.yaml`
con 7 candidatas, todas `enabled: false`); cada entrada pasa la
shape validation de `scripts/openclaw-contracts.sh` y el negative
test 13 prueba que cualquier intento de pasar una a `enabled: true`
es rechazado. `policy check` mantiene `tool registry: ningún tool
enabled` mientras eso siga. El siguiente paso técnico antes de
Beta-1 es **sandbox real + filesystem boundaries + confirmation
gate ejecutable**: implementar el wrapper que el contrato describe,
no agregar más entradas al registry.

## Amenazas principales

Las amenazas se ordenan por impacto si ocurrieran *con OpenClaw real
prendido*. En Beta-0 muchas son hipotéticas porque no hay runtime,
pero son las que tiene que prevenir el diseño futuro.

1. **Ejecución accidental.** Que un usuario, un script de Watson, un
   error de copy-paste o una regresión en el código termine
   ejecutando código real cuando se esperaba dry-run.
2. **`sudo` accidental.** Cualquier path que permita escalar
   privilegios — directa (`sudo`) o indirectamente (binarios suid,
   herramientas que escriben en paths protegidos).
3. **Red no autorizada.** Salidas a Internet u otros hosts sin
   intención explícita: agentes que descarguen modelos, paquetes,
   exploits, o que filtren contenido local.
4. **Acceso fuera del workspace.** Lecturas/escrituras a paths que
   no son `~/.patrick-os/workspaces/<modo>/`: notas personales,
   `~/.ssh/`, dotfiles, claves, scripts del sistema.
5. **Plugins externos.** Carga de binarios o scripts no shippeados
   en el repo PatrickOS — incluso si parecen "seguros". Cualquier
   discovery / auto-install abre la superficie a código no
   revisado.
6. **Policy drift.** La policy YAML cambia (manualmente o por
   automatización) sin que el cambio pase por revisión, y el
   sistema arranca con invariantes débiles.
7. **Ejecución sin aprobación humana.** Que el agente decida solo
   "este plan es suficientemente claro, lo corro". La aprobación
   tiene que ser un acto explícito por plan, no un toggle global.

## Controles actuales (Beta-0)

Cada control mapea a código concreto. Si la línea no apunta a un
archivo del repo, no es un control implementado — es intención
futura y va en la sección siguiente.

- **Dry-run por construcción.** `openclaw-stub.sh run` solo escribe
  markdown y un TSV; no hace `exec`/`subprocess` con tareas. La
  ejecución real no está implementada en ningún path de Beta-0.
- **Policy YAML (`configs/openclaw-policy.yaml`).** Declara las
  invariantes seguras (`network/sudo/plugins/marketplace: disabled`,
  `tool_whitelist: []`, `kill_switch: true`).
  `openclaw-policy.sh check` las valida con `grep -E` literal contra
  el archivo, sin parser YAML externo (menos dependencia, menos
  superficie). FAIL exit 1 si alguna invariante no se cumple.
- **Policy gate antes de cada run/execute.** `openclaw-stub.sh`
  invoca `openclaw-policy.sh check` antes de tocar nada. Si la
  policy falla, no se escribe plan, no se modifica workspace.
- **Kill switch local** (`$PATRICK_OS_HOME/openclaw/KILL_SWITCH`).
  Pausa táctica del usuario: mientras el archivo existe, `claw run`
  y `claw execute` abortan **antes** del policy gate. Gana sobre la
  policy. Comandos: `watson claw kill ["razón"]` / `watson claw
  unkill`.
- **Workspace sandbox lógico.** OpenClaw solo escribe en
  `$PATRICK_OS_HOME/workspaces/<modo>/`. El path se construye desde
  un set fijo de modos (`mode_allowed`) sin templating dinámico.
  Comandos que leen archivos por nombre (`show-plan`,
  `approve-plan`, `reject-plan`, `plan-status`, `execute`) exigen
  basename estricto: cualquier `/` o `..` se rechaza con exit 1
  antes de tocar el FS.
- **Audit log estructurado** (`openclaw/audit.log`). Una línea por
  evento, formato `timestamp | event=… | mode=… | result=… |
  detail=…`. 13 eventos en el catálogo
  (`openclaw-audit.sh summary`), incluyendo los 4 del execution
  gate. Append-only; ningún comando borra entradas.
- **Approval state.** Cada plan puede marcarse `approved` o
  `rejected` por separado. El sidecar es local y per-plan; no hay
  "aprobación global".
- **Execution gate `blocked-by-design`.** `claw execute` corre la
  cadena completa (kill switch + policy + aprobación) y, si todo
  pasa, igual termina en `blocked-by-design` con exit 1. En Beta-0
  ningún path puede ejecutar herramientas; este comando deja el
  flujo probado.
- **Doctor checks.** `watson doctor` corre smokes end-to-end de
  cada gate (run, viewer, search, approval, execute, audit). Si un
  control de seguridad se rompe en silencio, el doctor lo destapa
  en la siguiente corrida.
- **Sin red por código.** Ningún script Beta-0 hace `curl`, `wget`,
  `ssh`, ni abre sockets. `validate-system.sh` y `install.sh`
  tampoco — la instalación es local por archivos.
- **Sin `sudo` automático.** `install.sh` pide sudo explícitamente
  con la advertencia visible; ningún script de runtime
  (`openclaw-stub.sh`, `openclaw-policy.sh`, `openclaw-audit.sh`,
  `workspace.sh`, `doctor.sh` sin `repair`) lo invoca.

## Límites actuales (lo que el diseño NO cubre)

Estos límites son explícitos. La sección "Próximos controles" abajo
es la lista de qué hay que sumar antes de que tenga sentido prender
ejecución real.

- **No hay sandbox a nivel kernel.** Si un script bash se rompe y
  ejecuta algo, el proceso corre con todos los permisos del usuario.
  Beta-0 vive de que ningún path llame a herramientas reales — es
  un contrato del código, no una jaula.
- **No hay contenedor.** No usamos `bwrap`, `firejail`, docker,
  systemd-nspawn ni similar. El workspace es "sandbox" solo en el
  sentido de convención: el código solo escribe ahí.
- **No hay perfil `seccomp` / `AppArmor` propio.** El sistema base
  no tiene policy específica para OpenClaw; lo que hay es lo que
  vino con la distro.
- **No hay runtime real.** No existe el motor que ejecuta
  herramientas. Toda la cadena de gates es "qué pasaría si
  existiera"; el blocked-by-design del execute lo deja transparente.
- **YAML validado por grep.** `openclaw-policy.sh check` matchea
  líneas literales en vez de parsear YAML. Es robusto para el
  shape actual (chico y predecible) pero no toleraría una policy
  más compleja. Si el archivo crece, hay que reescribir el
  validador.
- **Audit log no firmado.** Es append-only por convención (todos
  los writers usan `>>`), pero un proceso malicioso con permisos
  del usuario podría reescribirlo. No hay hash chain ni signing.
- **Sin límites de rate / tamaño.** Un script con un loop podría
  llenar el `audit.log` o el `plans/` dir; no hay rotación ni
  budget por sesión.

## Próximos controles (antes de ejecución real)

Lista mínima para abrir la puerta a Beta-1 con la primera
herramienta. Cada item es un PR potencial; ninguno está en código
hoy.

- **Sandbox a nivel proceso.** Envolver la ejecución de cada
  herramienta en `bwrap` (o equivalente disponible en la ISO) con
  mounts mínimos: solo lectura del binario + lectura/escritura del
  workspace.
- **Tool contracts + allowlist.** El siguiente control técnico antes
  de habilitar cualquier ejecución es el contrato de herramientas
  definido en [`OPENCLAW_TOOL_CONTRACTS.md`](OPENCLAW_TOOL_CONTRACTS.md):
  cada herramienta tiene que declarar `allowed_modes`, `allowed_args`,
  `denied_args`, `filesystem_scope`, `network`, `sudo`,
  `timeout_seconds`, `requires_confirmation` y `log_level` antes de
  entrar a `configs/openclaw-tools.yaml`. El runtime real solo puede
  ejecutar binarios cuya ruta absoluta está en esa allowlist. La
  primera herramienta entra en un PR aparte con su propia revisión
  de seguridad.
- **Confirmación humana obligatoria por step.** Un plan aprobado da
  derecho a *intentar* la ejecución; cada step del plan, en el
  futuro, requiere su propio prompt interactivo. Sin TTY ⇒ no
  ejecuta.
- **Network namespace / red bloqueada.** El proceso de la
  herramienta corre en un namespace de red sin `lo` ni rutas
  externas. La excepción "una herramienta de red" entra en otro PR
  con su propio gate.
- **Límites de filesystem.** Bind-mount read-only de todo lo que no
  sea el workspace. Sin acceso a `$HOME` (fuera de `.patrick-os/`),
  sin acceso a `/etc`, sin escritura a `/tmp` salvo el workspace.
- **Audit log append-only de verdad.** Abrir el archivo con
  `O_APPEND` desde un helper privilegiado (o usar `chattr +a` donde
  el FS lo permita) para que el propio runtime no pueda reescribir
  su propio rastro.
- **Tests negativos.** Suite que ejerza cada control: intentar
  llamar una herramienta no whitelisted, intentar tocar `$HOME`
  fuera del workspace, intentar abrir un socket. Cada test asume
  que la herramienta es maliciosa y verifica que es bloqueada.
- **Rotación / budget.** Tamaño máximo del `audit.log`, número
  máximo de planes históricos, tiempo total de ejecución por
  sesión.

Cualquier PR que toque la cadena de gates, la policy, el catálogo
de eventos o el set de controles tiene que actualizar este documento
en el mismo cambio.
