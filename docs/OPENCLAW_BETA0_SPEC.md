# OpenClaw Beta-0 — Spec

Estado: **propuesta**. Este documento describe el contrato de la primera
beta de OpenClaw dentro de PatrickOS. **OpenClaw runtime real sigue NO
implementado.** Beta-0 entrega únicamente el camino seguro y el dry-run;
el motor que ejecuta herramientas reales llega después.

## Roles

- **Watson** = identidad del usuario, interfaz CLI y *border guard*.
  Recibe comandos, valida permisos, decide si una operación puede
  delegarse, y traduce la respuesta de OpenClaw en algo presentable.
  Es el único que habla con el usuario.
- **OpenClaw** = motor agéntico futuro. Recibe una tarea acotada
  desde Watson, propone un plan y (cuando exista runtime real)
  ejecuta herramientas dentro de un sandbox.

OpenClaw nunca habla con el usuario directo. Watson nunca ejecuta
herramientas del motor agéntico fuera del contrato de Beta-0.

## Comunicación

- **Transporte:** stdin/stdout, o socket UNIX en `~/.patrick-os/run/openclaw.sock`.
  **Nada de TCP**, ni siquiera localhost.
- **Modelo de proceso:** OpenClaw es **subproceso** lanzado por Watson
  por invocación. **No es daemon**, no queda corriendo en background,
  no se autoarranca al boot.
- **Formato:** JSON línea-a-línea (`ndjson`) para que sea trivial
  loggear y diffear. Sin frameworks de RPC.
- **Timeout:** cada invocación tiene timeout duro (default conservador,
  ej. 30 s para Beta-0); si vence, Watson mata el subproceso.

## Aislamiento

- **Workspace permitido:** `~/.patrick-os/workspaces/<modo>/`.
  OpenClaw solo puede leer/escribir dentro de su workspace de modo
  (`dev`, `consulta`, `clase`, `video`, etc.). Cualquier path fuera
  se rechaza desde Watson antes de pasar el request.
- **Whitelist de herramientas:** **vacía por defecto.** En Beta-0 no
  hay ninguna herramienta habilitada de fábrica. Habilitar una
  herramienta es un cambio de código revisado, no un toggle en
  config de usuario.
- **Sin `sudo`.** OpenClaw corre como el mismo usuario que Watson y
  nunca puede escalar privilegios. Watson rechaza cualquier request
  que requiera root.
- **Sin red por defecto.** Beta-0 no expone ninguna herramienta de
  red. Cuando exista una en el futuro, requiere whitelist explícita
  por host.
- **Sin plugins externos.** No se cargan binarios, scripts ni paquetes
  desde fuera del repo PatrickOS. No hay mecanismo de descubrimiento
  ni de auto-install.
- **Sin marketplace.** No existe, no se va a existir como parte de
  esta línea de producto.

## Observabilidad

- **Logs mínimos** en `~/.patrick-os/logs/openclaw.log`:
  timestamp, comando recibido, modo, decisión (`accepted` /
  `rejected` / `dry-run`), duración, exit code. **Sin** stdout/stderr
  de las herramientas en Beta-0 (no hay herramientas todavía).
- Sin telemetría remota. Nunca.

## Kill switch

- **Kill switch local** vía archivo: si existe
  `~/.patrick-os/openclaw.disabled`, Watson rechaza cualquier
  invocación a OpenClaw con un mensaje claro y exit code no-cero.
  El archivo lo crea/borra el usuario a mano. Sin daemon, sin
  servicio, sin reinicios.

## Comando propuesto

```bash
watson claw run "tarea"
```

En **Beta-0**:

- `watson claw run "..."` arranca OpenClaw como subproceso, le pasa
  la tarea, recibe un **plan** (lista de pasos propuestos) y lo
  imprime.
- **No ejecuta herramientas reales.** El modo efectivo es `dry-run`
  / `plan-only`. Cualquier paso del plan se imprime como "would
  run", nunca se corre.
- `watson claw` (sin `run`) sigue siendo el stub actual mientras el
  contrato no esté en código.

## Lo que Beta-0 deja afuera (explícito)

- Ejecución de herramientas reales.
- Memoria persistente entre invocaciones más allá del workspace.
- Acceso a `~/.patrick-os/notes/` y `~/.patrick-os/todos/` desde
  OpenClaw (Watson sigue siendo el único que toca esos archivos).
- Multi-step autónomo: en Beta-0 cada invocación es un único
  round-trip plan-only.
- UI gráfica de cualquier tipo.

## Cuándo pasa a Beta-1

Beta-1 (no en v0.3) podrá empezar a habilitar herramientas
**una por una** con whitelist explícita, dentro del mismo contrato
de transporte / aislamiento / kill switch que define Beta-0. Si el
contrato necesita cambiar para Beta-1, se hace en un PR separado
con su propia revisión.
