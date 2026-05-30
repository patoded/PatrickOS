# PatrickOS

Distribución Linux personalizada basada en Debian/Ubuntu, optimizada para
trabajo médico, docente y de desarrollo, con un agente local llamado **Watson**
que orquesta el sistema desde la línea de comandos y se apoya en IA local vía
**Ollama**.

## Estado

`v0.2.0-alpha` publicada (código y docs); ciclo **`v0.3.0-dev`** en
curso (preparación agéntica segura con OpenClaw Beta-0, sin ejecución
real). ISO v0.3 postergada por diseño; ver `docs/V0.3_PLAN.md`.

- Watson CLI con modos (consulta, clase, video, desarrollo, IA, preguntar IA),
  más comandos meta: `ayuda`, `version`, `estado`, `sistema`, `validar`,
  `release`, `salir`. Cada uno tiene alias corto (`h`, `v`, `st`, `sys`,
  `val`, `rel`, `dev`, `ia`, `ask`, `q`); ver `watson ayuda` para la lista.
- Scripts externos para cada modo, validación de sistema
  (`validate-system.sh`) y checklist de release (`release-checklist.sh`).
- Manejo de errores robusto (`FileNotFoundError`, `PermissionError`,
  `CalledProcessError`).
- ISO booteable en QEMU/VirtualBox: en iteración Alpha (ver `docs/INSTALL.md`).
- Versionado: las releases se publicarán como tags `vX.Y.Z-alpha` con
  notas en `docs/RELEASE-vX.Y.Z-alpha.md` cuando estén listas.

## Quickstart

```bash
git clone https://github.com/<usuario>/patrick-os.git
cd patrick-os

# Dependencias base de desarrollo (apt; pide sudo).
bash scripts/setup-dev.sh

# Correr Watson desde el repo.
make watson

# O instalarlo como comando del sistema y verificar la instalación.
sudo bash scripts/install.sh
make check-installed
watson inicio
```

`install.sh` copia `watson.py` a `/usr/local/bin/watson`, los `scripts/*.sh`
a `/usr/local/share/patrick-os/scripts/`, los `docs/*.md` a
`/usr/local/share/patrick-os/docs/`, y al final corre una verificación
post-install que aborta con exit 1 si la versión instalada difiere de
la del repo o si falta algún script crítico (`home.sh`, `daily.sh`,
`notes.sh`, `todos.sh`, `workspace.sh`, `openclaw-stub.sh`,
`validate-system.sh`).

`make check-installed` re-ejecuta esa verificación en cualquier momento
sin sudo. Compara versión y hace `cmp` byte-a-byte de cada script
crítico y de los docs clave (`README.md`, `ARCHITECTURE.md`,
`PROJECT_CONTEXT.md`) contra el repo. Si algo difiere, sugiere reinstalar.

Para un diagnóstico todo-en-uno (repo limpio, `make check`, instalación
global en sync, `watson version/validar`, y smokes de workspace +
OpenClaw dry-run) usá:

```bash
watson doctor          # alias: doc
# o:  make doctor
```

Reporta `[OK]/[WARN]/[FAIL]` por sección con resumen final
`OK=n WARN=n FAIL=n`. Exit code = nº de FAILs. Los smokes corren en
sandbox `/tmp/patrick-doctor` (no toca `~/.patrick-os`). Si la
instalación global está desactualizada, doctor imprime al final
`Reparación sugerida: sudo bash scripts/install.sh`.

Para reparar en el mismo flujo (pide sudo y luego re-corre el
diagnóstico):

```bash
watson doctor repair   # también: make doctor-repair
```

## Flujo rápido de desarrollo

```bash
scripts/new-branch.sh feat/algo                       # rama desde main al día
make check                                            # lint + smoke pre-PR
scripts/pr-create.sh main "feat: algo"                # abre PR (= make pr TITLE=...)
scripts/pr-merge.sh                                   # squash + back to main (= make merge)
```

Atajos vía Makefile: `make check`, `make pr TITLE="..."`, `make merge [PR=N]`.

Si `make check` falla con `[FAIL] check-executable-scripts`, algún
`scripts/*.sh` perdió `+x` (típico al editarse desde Windows/WSL share).
Rescate: `make fix-perms` y volver a correr `make check`.

Para hacer preguntas locales a Ollama con el contexto del proyecto:

```bash
./scripts/ask-local.sh "¿Qué módulos define PatrickOS?"
```

(Requiere Ollama instalado y el modelo `llama3.2:3b` descargado.)

## Estructura

```
patrick-os/
├── watson/          # Watson CLI (Python)
├── scripts/         # Scripts bash de cada modo + instalador
├── docs/            # README, ARCHITECTURE
├── configs/         # (Vacío) Configuración XFCE y sistema (Día 5)
├── branding/        # (Vacío) Logos, wallpapers (Día 5)
├── iso/             # (Vacío) Pipeline live-build (Día 4)
├── Makefile         # Targets: watson, install, test, lint, iso, clean
└── README.md
```

Detalles de diseño en [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md).
Contexto del proyecto: [`docs/PROJECT_CONTEXT.md`](docs/PROJECT_CONTEXT.md).
Checklist v0.2.0-alpha: [`docs/V0.2_ALPHA_CHECKLIST.md`](docs/V0.2_ALPHA_CHECKLIST.md).
Release notes v0.2.0-alpha: [`docs/RELEASE_NOTES_v0.2.0-alpha.md`](docs/RELEASE_NOTES_v0.2.0-alpha.md).
Plan v0.3: [`docs/V0.3_PLAN.md`](docs/V0.3_PLAN.md).
Spec OpenClaw Beta-0: [`docs/OPENCLAW_BETA0_SPEC.md`](docs/OPENCLAW_BETA0_SPEC.md).
Release notes v0.3.0-alpha: [`docs/RELEASE_NOTES_v0.3.0-alpha.md`](docs/RELEASE_NOTES_v0.3.0-alpha.md).
Checklist v0.3.0-alpha: [`docs/V0.3_ALPHA_CHECKLIST.md`](docs/V0.3_ALPHA_CHECKLIST.md).

## Validar antes de publicar

Apuntá `release-checklist.sh` a la versión target. Durante el ciclo
de desarrollo Watson reporta `vX.Y.Z-dev` mientras el target ya es
`vX.Y.Z-alpha`; el checklist marca eso como `TODO` (no `FAIL`) y
recuerda bumpear `_VERSION` al tagear.

```bash
make check
scripts/release-checklist.sh v0.3.0-alpha   # ciclo actual
scripts/release-checklist.sh v0.2.0-alpha   # release publicada
```

`release-checklist.sh` reporta `OK`/`TODO`/`FAIL`: `FAIL` bloquea,
`TODO` (ej. ISO no construida todavía, `_VERSION` aún en `-dev`) es
esperado durante el ciclo. Exit code = nº de FAILs.

## Notas rápidas

Capturar y listar notas locales desde la terminal, sin abrir editor:

```bash
watson nota "idea: caching de modelos por sesión"   # alias: n
watson notas                                        # alias: ns, notes
```

Las notas viven en `~/.patrick-os/notes/notes.md` como texto plano,
una línea por nota con timestamp:

```
2026-05-28 10:07:14 | idea: caching de modelos por sesión
```

`watson notas` muestra las 20 más recientes. Si todavía no hay
archivo, dice `Sin notas.`. Para tests o sandbox, override la
ruta con `PATRICK_OS_NOTES_DIR=/tmp/notes`.

## Tareas rápidas

Pendientes simples desde la terminal, con marcado de hecho. Almacenadas
en `~/.patrick-os/todos/todos.md` como Markdown con checkboxes:

```bash
watson tarea "preparar guion del video"   # alias: t, todo
watson tareas                             # alias: ts, todos
watson tarea done 3                       # marca la tarea 3 como hecha
```

`watson tareas` muestra las 30 más recientes con su número (1..N), que
es estable aunque la lista se truncue: ese mismo número se usa con
`tarea done <n>`. Si no hay archivo: `Sin tareas.`. Sandbox vía
`PATRICK_OS_TODOS_DIR=/tmp/todos`.

## Resumen diario

Vista rápida del día sin abrir los archivos: notas de hoy, tareas
pendientes y tareas completadas hoy, leídas de los mismos archivos
locales que `watson nota` y `watson tarea`.

```bash
watson diario   # alias: d, daily
```

Salida:

```
PatrickOS Daily
Fecha: 2026-05-28

Notas de hoy:
2026-05-28 10:07:14 | idea: caching de modelos por sesión

Tareas pendientes:
- [ ] 2026-05-27 18:22:01 | preparar guion del video

Tareas completadas hoy:
- [x] 2026-05-28 09:14:33 | revisar PR #13
```

Si alguna sección no tiene contenido, dice `Sin notas de hoy.` /
`Sin tareas pendientes.` / `Sin tareas completadas hoy.`. Cada sección
muestra hasta 10 entradas. Sandbox: `PATRICK_OS_NOTES_DIR` y
`PATRICK_OS_TODOS_DIR` aplican igual que en `nota` / `tarea`.

## Home dashboard

Panel rápido tipo "home" para arrancar el día sin abrir cinco comandos
distintos. Combina versión de Watson, estado de sistema, el resumen
diario y un cheatsheet de atajos:

```bash
watson inicio   # alias: i, home, panel
```

Secciones (todas locales, sin red):

- **Estado Watson:** versión actual (`v0.3.0-dev`).
- **Sistema:** `hostname`, `uptime -p` (con fallback a `uptime` plano si
  la flag no está soportada), y `free -h` resumida.
- **Daily:** delega en `daily.sh` si está presente y ejecutable. Si
  todavía no se instaló, lo dice y sigue.
- **Atajos:** cheatsheet de los comandos más usados (`nota`, `tarea`,
  `diario`, `ia`, `claw`).

Hereda `PATRICK_OS_NOTES_DIR` y `PATRICK_OS_TODOS_DIR` al delegar en
`daily.sh`, así que el sandbox de notas/tareas funciona igual.

## Workspaces locales

Gestión simple de directorios de trabajo por modo. Es la base concreta
del aislamiento por modo que pide OpenClaw Beta-0: `claw run --mode <m>`
delega aquí la creación del workspace antes de escribir su plan.

```bash
watson ws list                       # alias de workspace
watson ws init desarrollo
watson ws path desarrollo
watson ws clean desarrollo           # bloqueado sin --yes
watson ws clean desarrollo --yes     # vacía y recrea README.md
```

Modos permitidos: `consulta`, `clase`, `video`, `desarrollo`, `ia`,
`general`. Cualquier otro → exit 1.

Cada workspace vive en `~/.patrick-os/workspaces/<modo>/` con un
`README.md` con el modo y la fecha de creación. `init` es idempotente:
si ya hay README, no lo sobrescribe (las ediciones del usuario se
respetan). `clean --yes` borra todo el contenido y recrea el README;
sin `--yes` solo imprime cómo confirmar y sale en 1. Sandbox vía
`PATRICK_OS_HOME=/tmp/...` (mismo override que usa `claw`).

## OpenClaw audit log

Bitácora estructurada y append-only de eventos de OpenClaw (status,
policy, kill, unkill, runs permitidos y bloqueados). Una línea por
evento, formato estable:

```
YYYY-MM-DD HH:MM:SS | event=<evento> | mode=<modo> | result=<ok|blocked|fail|info> | detail=<texto>
```

Archivo: `~/.patrick-os/openclaw/audit.log` (respeta `PATRICK_OS_HOME`).
Lectura vía Watson:

```bash
watson audit            # alias: aud — últimas 20 (default = tail)
watson audit list       # log completo
watson audit tail       # últimas 20
watson audit path       # imprime ruta del archivo
watson audit summary    # conteo por evento (kill / unkill / run_allowed / ...)
```

`watson doctor` corre un smoke del audit log: tras el `claw run` de
prueba verifica que `audit.log` se creó y que `audit summary` corre
contra él.

Eventos registrados: `status`, `policy`, `kill`, `unkill`,
`run_allowed`, `run_blocked_kill_switch`, `run_blocked_policy`,
`run_invalid_mode`, `run_empty_task`. El detail incluye la tarea o
la razón del kill cuando aplica; no se registra nada más allá de
texto que el usuario tipeó.

## OpenClaw kill switch

Pausa táctica del usuario sobre OpenClaw. Materializada como un archivo
local en `~/.patrick-os/openclaw/KILL_SWITCH` (respeta `PATRICK_OS_HOME`).
Mientras el archivo exista, **ningún `claw run` se ejecuta** — ni
siquiera el dry-run. Gana sobre la policy: aunque el YAML sea seguro,
el switch bloquea.

```bash
watson claw kill "pausa de seguridad"   # crea el archivo con razón
watson claw kill                        # crea el archivo sin razón
watson claw status                      # muestra estado del switch
watson claw unkill                      # borra el archivo
```

`policy check` sigue pasando con el switch activo (no es una falla
de la policy) pero reporta `[INFO] KILL_SWITCH activo`.
`watson validar` lo levanta como `WARN` cada vez que corre.

## OpenClaw policy layer

Antes de cualquier dry-run, OpenClaw consulta una policy local
explícita (`configs/openclaw-policy.yaml`) que declara invariantes
seguras: red deshabilitada, sudo deshabilitado, plugins y marketplace
deshabilitados, `tool_whitelist: []`, `kill_switch: true`. Si alguna
invariante no se cumple, `claw run` aborta **antes** de tocar el
workspace.

```bash
watson policy           # alias: pol — imprime la policy en uso
watson policy check     # valida invariantes; exit 1 si algo es inseguro
watson claw policy      # idem, vía el openclaw stub
```

`configs/openclaw-policy.yaml` se copia a
`/usr/local/share/patrick-os/configs/` al instalar; `check-installed`
y `make doctor` exigen que esté en sync con el repo.

## OpenClaw: stub seguro

Watson tiene cableado el comando `openclaw` (alias `claw`) como **stub
seguro**. No carga runtime, no toca red, no ejecuta herramientas. Sin
argumentos muestra el estado:

```bash
watson openclaw   # o: watson claw
# OpenClaw Runtime: stub
# Estado: no instalado / no activo
# Modo seguro: sin ejecución de herramientas
# Beta-0 dry-run disponible: openclaw-stub.sh run "tarea"
# Próximo paso: integrar runtime aislado con whitelist
```

## OpenClaw Beta-0 dry-run

`watson claw run "tarea"` corre el dry-run de Beta-0: registra la tarea,
crea un workspace aislado por modo y escribe un plan markdown. **No
ejecuta herramientas reales, no usa red, no escala privilegios.**

```bash
watson claw run "prepara estructura de proyecto"
watson claw run --mode clase "plan para clase"
```

Modo default: `desarrollo`. Modos permitidos: `consulta`, `clase`,
`video`, `desarrollo`, `ia`, `general` (cualquier otro → exit 1).
Tarea vacía → uso + exit 1.

Cada `run` genera/actualiza:

- `~/.patrick-os/workspaces/<modo>/last-plan.md` — último plan (se
  sobrescribe en cada invocación; si el `KILL_SWITCH` está activo o
  el policy gate falla, **no se escribe nada**).
- `~/.patrick-os/workspaces/<modo>/plans/<YYYYMMDD-HHMMSS>-plan.md`
  — copia histórica inmutable del mismo plan. `watson ws plans <modo>`
  lista los archivos del historial (o `Sin planes.` si todavía no
  hubo runs en ese modo).
- Visualización rápida sin abrir editor:

  ```bash
  watson ws last-plan desarrollo                  # imprime last-plan.md
  watson ws show-plan desarrollo latest           # equivalente
  watson ws show-plan desarrollo 20260530-123208-plan.md
  ```

  `show-plan` solo acepta **basename** dentro de `<workspace>/plans/`;
  paths con `/` o `..` se rechazan con exit 1.
- `~/.patrick-os/workspaces/<modo>/plans/index.tsv` — índice
  append-only para listar planes sin abrir cada `.md`:

  ```
  timestamp<TAB>mode<TAB>filename<TAB>task
  ```

  Una línea por `claw run` permitido. `watson ws plan-index <modo>`
  lo imprime (`Sin índice de planes.` si todavía no hubo runs).
- Búsqueda y listado rápido sobre el índice:

  ```bash
  watson ws recent desarrollo               # últimos 5 (default)
  watson ws recent desarrollo 10            # últimos N
  watson ws search desarrollo "clase"       # case-insensitive, fixed-string
  ```

  Formato de salida: `timestamp | filename | task` (sin la columna
  modo, que ya viene en la query). `recent` y `search` solo leen
  `index.tsv`; sin red, sin herramientas externas.
- `~/.patrick-os/openclaw/openclaw.log` — log append-only,
  `timestamp | mode=... | dry-run | task=...`.
- `~/.patrick-os/openclaw/audit.log` — bitácora estructurada (ver
  sección "OpenClaw audit log" arriba).

Formato del plan (`last-plan.md`):

```markdown
# OpenClaw Dry Run Plan

## Metadata
Fecha: 2026-05-30 12:00:00
Modo: desarrollo
Workspace: ~/.patrick-os/workspaces/desarrollo
Policy: OK
Tool whitelist: empty
Kill switch: disabled

## Tarea solicitada
prepara estructura de proyecto

## Interpretación
prepara estructura de proyecto

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

Sandbox para tests: `PATRICK_OS_HOME=/tmp/pr-openclaw` redirige tanto
log como workspaces. Contrato completo en
[`docs/OPENCLAW_BETA0_SPEC.md`](docs/OPENCLAW_BETA0_SPEC.md).

## Roadmap (resumen)

| Fase | Estado |
|------|--------|
| 1. Entorno WSL2 | Completo |
| 2. Watson mínimo funcional | Completo |
| 3. Scripts de automatización | Completo |
| 4. Configuración del sistema (XFCE, branding) | En curso |
| 5. ISO custom booteable | Pendiente |

## Licencia

MIT. Ver [`LICENSE`](LICENSE).
