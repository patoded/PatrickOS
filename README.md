# PatrickOS

Distribución Linux personalizada basada en Debian/Ubuntu, optimizada para
trabajo médico, docente y de desarrollo, con un agente local llamado **Watson**
que orquesta el sistema desde la línea de comandos y se apoya en IA local vía
**Ollama**.

## Estado

Prototipo en fase **Alpha en construcción** (`v0.2.0-dev`).

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

# O instalarlo como comando del sistema.
make install
watson
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
Release notes v0.2.0-alpha: [`docs/RELEASE_NOTES_v0.2.0-alpha.md`](docs/RELEASE_NOTES_v0.2.0-alpha.md).

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

- **Estado Watson:** versión actual (`v0.2.0-dev`).
- **Sistema:** `hostname`, `uptime -p` (con fallback a `uptime` plano si
  la flag no está soportada), y `free -h` resumida.
- **Daily:** delega en `daily.sh` si está presente y ejecutable. Si
  todavía no se instaló, lo dice y sigue.
- **Atajos:** cheatsheet de los comandos más usados (`nota`, `tarea`,
  `diario`, `ia`, `claw`).

Hereda `PATRICK_OS_NOTES_DIR` y `PATRICK_OS_TODOS_DIR` al delegar en
`daily.sh`, así que el sandbox de notas/tareas funciona igual.

## OpenClaw: stub seguro

Watson tiene cableado el comando `openclaw` (alias `claw`) como **stub
no-op**. No carga runtime, no toca red, no ejecuta herramientas. Su único
papel hoy es reservar el comando y la ruta del script para que la
integración futura no requiera mover dispatch ni alias.

```bash
watson openclaw   # o: watson claw
# OpenClaw Runtime: stub
# Estado: no instalado / no activo
# Modo seguro: sin ejecución de herramientas
# Próximo paso: integrar runtime aislado con whitelist
```

Cuando exista el runtime real (aislado + con whitelist explícita de
herramientas), reemplaza el stub en su lugar. Esta sección NO promete
runtime real ni fecha.

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
