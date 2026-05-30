# PatrickOS / WatsonOS — Resumen operativo del proyecto

## Objetivo general

PatrickOS / WatsonOS es una distro Linux personalizada orientada a trabajo real, productividad médica, desarrollo de contenido, automatización local e integración progresiva de agentes de IA.

La meta no es hacer una distro "bonita" o académica, sino una estación de trabajo rápida, ligera, usable y automatizable para el Dr. Patrick Mendoza.

Prioridad: avanzar agresivamente, con mínima burocracia, pero con seguridad suficiente para no romper el proyecto.

## Filosofía de trabajo

* Avanzar rápido.
* Cambios pequeños o medianos, probables y verificables.
* Preferir comandos concretos sobre explicaciones largas.
* Evitar sobre-documentar.
* Evitar features grandes sin validación.
* Todo avance debe poder probarse rápido.
* GitHub debe usarse desde terminal, no manualmente.
* Opus/Codex pueden codificar; ChatGPT funciona como centro de dirección estratégica y operativa.
* Patrick quiere instrucciones tipo "haz esto", no discursos.

## Estado actual

Repositorio principal:
`patoded/PatrickOS`

PatrickOS ya tiene una primera Alpha publicada:
`v0.1.0-alpha`

`v0.2.0-alpha` cerró del lado de código y docs. La build de ISO v0.2
queda como decisión separada (ver `docs/V0.2_ALPHA_CHECKLIST.md` y
`scripts/release-checklist.sh v0.2.0-alpha`).

Ciclo actual: **`v0.3.0-alpha` en preflight**. Watson reporta
`v0.3.0-alpha`; código + docs cerrados, OpenClaw Beta-0 cerrado
como capa dry-run segura (ver `docs/OPENCLAW_BETA0_CHECKLIST.md`).
**Siguiente paso: construir ISO `v0.3.0-alpha`** en un PR aparte
una vez validado `scripts/release-checklist.sh v0.3.0-alpha`.

La Alpha incluye:

* ISO live basada en Ubuntu 24.04.
* Arranque funcional en QEMU.
* Escritorio XFCE funcional.
* Watson CLI instalado.
* zram activo.
* Teclado latinoamericano funcional.
* Perfil workstation ligero.
* Scripts base de PatrickOS.
* GitHub Release publicado con ISO y SHA256.

## Release Alpha publicado

Release:
`PatrickOS v0.1.0-alpha`

Estado:

* ISO publicada.
* SHA256 publicado.
* Tag `v0.1.0-alpha` creado.
* Release marcado como pre-release.
* No instalar todavía en hardware real.
* Validación principal: QEMU.

## Watson CLI

Watson es el agente/launcher local de PatrickOS.

Comandos actuales importantes:

* `ayuda`, `h`, `help`
* `version`, `v`, `ver`
* `estado`, `st`
* `sistema`, `sys`
* `validar`, `val`
* `release`, `rel`
* `modo desarrollo`, `dev`
* `modo ia`, `ia`
* `preguntar ia`, `ask`
* `openclaw`, `claw`
* `nota`, `note`, `n`
* `notas`, `notes`, `ns`
* `tarea`, `todo`, `t`
* `tareas`, `todos`, `ts`
* `diario`, `daily`, `d`
* `inicio`, `home`, `panel`, `i`
* `salir`, `q`, `exit`, `quit`

Watson soporta comandos directos desde terminal:

```bash
watson estado
watson ia
watson ask "resume PatrickOS"
watson nota "idea rápida"
watson tarea "pendiente rápido"
watson diario
watson inicio
```

Si se ejecuta sin argumentos, entra en modo interactivo.

## Funciones locales ya agregadas

### Notas rápidas

Comandos:

```bash
watson nota "texto"
watson n "texto"
watson notas
watson ns
```

Ruta:
`~/.patrick-os/notes/notes.md`

### Tareas rápidas

Comandos:

```bash
watson tarea "texto"
watson t "texto"
watson tareas
watson tarea done 1
```

Ruta:
`~/.patrick-os/todos/todos.md`

Formato:

```md
- [ ] YYYY-MM-DD HH:MM:SS | tarea pendiente
- [x] YYYY-MM-DD HH:MM:SS | tarea completada
```

### Resumen diario

Comandos:

```bash
watson diario
watson daily
watson d
```

Debe mostrar:

* Notas de hoy.
* Tareas pendientes.
* Tareas completadas hoy.

### Home dashboard

Comandos:

```bash
watson inicio
watson home
watson panel
watson i
```

Debe mostrar:

* Estado Watson.
* Sistema.
* Daily.
* Atajos útiles.

## OpenClaw

OpenClaw todavía NO está integrado como runtime real.

Estado actual:

* Existe un stub seguro.
* Comandos:

  * `watson openclaw`
  * `watson claw`

El stub solo informa:

* OpenClaw no instalado/no activo.
* Sin ejecución de herramientas.
* Modo seguro.
* Próximo paso: runtime aislado con whitelist.

Principio arquitectónico:

* Watson será la identidad, interfaz y guardia de permisos.
* OpenClaw será el motor agéntico futuro.
* OpenClaw no debe correr libremente.
* Debe tener whitelist de herramientas.
* Sin sudo.
* Sin marketplace.
* Sin red por defecto.
* Sin plugins externos por defecto.
* Aislamiento por workspace.

## Herramientas de desarrollo

Scripts importantes:

* `scripts/dev-check.sh`
* `scripts/pr-create.sh`
* `scripts/pr-merge.sh`
* `scripts/new-branch.sh`
* `scripts/check-executable-scripts.sh`
* `scripts/fix-script-perms.sh`
* `scripts/validate-system.sh`
* `scripts/release-checklist.sh`

Makefile:

* `make check`
* `make fix-perms`
* `make pr`
* `make merge`

GitHub CLI quedó instalado localmente en:
`~/.local/bin/gh`

Debe estar en PATH:

```bash
export PATH="$HOME/.local/bin:$PATH"
```

Esto ya está agregado a `~/.bashrc`.

## Flujo rápido de desarrollo

Crear rama:

```bash
scripts/new-branch.sh feat/nombre
```

Probar:

```bash
make check
```

Crear PR:

```bash
scripts/pr-create.sh main "titulo del PR"
```

Mergear PR:

```bash
gh pr merge --squash --delete-branch
git checkout main
git pull
git status
```

Regla: no hacer PR manual desde navegador salvo emergencia.

## Bugs resueltos

* `boot=live` causaba kernel panic; se corrigió a `boot=casper`.
* La ISO ya arranca con GRUB.
* Se estabilizó empaquetado con `grub-mkrescue`.
* Se corrigió teclado latinoamericano.
* Se corrigió problema repetido de scripts `.sh` sin bit ejecutable.
* Se agregó validación para detectar scripts sin `+x`.
* Se instaló y configuró `gh` sin depender de `sudo`.
* Se arregló WSL cuando `WSLService` estaba deshabilitado.
* Se cambió la distro default de WSL a Ubuntu.

## Decisiones importantes

* No meter NVIDIA propietario todavía.
* No meter OpenClaw runtime real todavía.
* No meter Firefox, LibreOffice, OBS todavía.
* No meter CI pesado todavía.
* No tocar ISO en cada PR pequeño.
* Priorizar Watson como interfaz central.
* Priorizar velocidad de uso: aliases, comandos directos, notas, tareas, resumen diario y dashboard home.
* La distro debe facilitar copiar/pegar, múltiples ventanas y terminal usable.
* Cada cambio debe poder validarse con `make check`.

## Próximos pasos inmediatos

1. Mergear el PR de preflight v0.3.0-alpha (este).
2. Construir ISO `v0.3.0-alpha` en un PR aparte, una vez que `scripts/release-checklist.sh v0.3.0-alpha` quede sin FAILs (TODOs de ISO/tag son esperados hasta ese build).
3. Tagear `v0.3.0-alpha` cuando la ISO esté lista y validada.
4. Recién después abrir Beta-1 de OpenClaw (primera herramienta whitelisted, todavía sin red ni sudo; requiere los controles del modelo de seguridad: sandbox real, allowlist concreta, confirmación humana por step, FS boundaries, negative tests).

## Próximo foco: v0.3 / OpenClaw Beta-0

Tras cerrar v0.2 (código + ISO), el siguiente avance es v0.3:
release de **preparación**, no de runtime agéntico.

Foco:

* Mejorar instalación global (`install.sh` + refresco de scripts en `/usr/local/share/patrick-os/`).
* Iterar sobre `watson inicio` / `watson home` con feedback de uso diario.
* Aterrizar el contrato de **OpenClaw Beta-0**: transporte por stdin/stdout o socket UNIX (sin TCP), subproceso (no daemon), workspaces aislados en `~/.patrick-os/workspaces/<modo>/`, whitelist de herramientas vacía por defecto, sin sudo, sin red, sin plugins externos, sin marketplace, logs mínimos, kill switch local vía `~/.patrick-os/openclaw.disabled`.
* Mantener ISO v0.2 estable; reconstruir ISO v0.3 **solo al final** de v0.3.

Aclaración explícita:

* **OpenClaw runtime real sigue NO implementado.** Beta-0 entrega
  únicamente el contrato y un `watson claw run "tarea"` en modo
  `dry-run` / plan-only — no ejecuta herramientas reales.

Referencias:

* `docs/V0.3_PLAN.md`
* `docs/OPENCLAW_BETA0_SPEC.md`

## Regla de interacción con Patrick

Patrick no quiere explicaciones largas salvo que las pida.

Formato preferido:

1. Qué hacer.
2. Comandos.
3. Prompt para Opus/Codex si aplica.
4. Validación mínima.
5. Siguiente paso.

Evitar:

* Burocracia innecesaria.
* Planes largos sin ejecución.
* Repetir teoría.
* Mezclar proyectos externos como WHATSON VPS con PatrickOS.
* Pedir confirmación para cada detalle menor.

## Estado mental del proyecto

Ya no estamos "intentando hacer una distro".

Ya existe:

* ISO Alpha publicada.
* Watson funcional.
* GitHub workflow operativo.
* Comandos rápidos.
* Base para IA local.
* Base para integración agéntica futura.
* Sistema de notas/tareas/daily/home.

La misión ahora es convertir PatrickOS en una estación de trabajo diaria, útil y automatizable, avanzando por PRs pequeños y rápidos.
