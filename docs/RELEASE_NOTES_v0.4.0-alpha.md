# PatrickOS v0.4.0-alpha

## Estado

**Preflight listo para build ISO.** Watson reporta
`v0.4.0-alpha`. Esta release cierra el ciclo de **safety
foundation de OpenClaw Beta-1 simulada**: toda la cadena de
gates, contratos, validadores, registros y reportes está en
código y verificada por la suite obligatoria.

**`ready_for_real_execution=no` sigue siendo invariante por
diseño.** El runtime real de OpenClaw NO está implementado y no
se habilita en esta release.

El build de la ISO `v0.4.0-alpha` queda como PR posterior.

## Incluido

- **OpenClaw Beta-1 simulated readiness gate**
  (`scripts/openclaw-readiness.sh`, `watson readiness`,
  `make readiness`) — reporta
  `ready_for_simulated_beta1=yes` mientras la cadena de OK pase
  (policy, contracts, tools registry disabled, negative tests,
  doctor, execution gate blocked-by-design, simulated binding,
  simulated execution manifest, execution manifest index) y
  `[BLOCKED] real execution runtime not implemented` como
  estado terminal esperado.
- **Negative tests automatizados**
  (`scripts/openclaw-negative-tests.sh`, `watson negative-tests`,
  `make negative-tests`) — 28 pruebas que ejercitan cada gate
  (policy tampered, kill switch, missing approval, basename
  traversal, tag/priority/modo inválidos, tools registry
  tampered, simulate tool desconocida, simulate-execute binding,
  execution manifest, index, search, audit report).
- **Contracts validator** (`scripts/openclaw-contracts.sh`,
  `watson contracts check`) — valida shape mínima (12 campos)
  por entrada de `configs/openclaw-tools.yaml` + reglas duras
  (sin `sudo`, sin red, names seguros, `requires_confirmation`
  true).
- **Tool allowlist `disabled`** — `configs/openclaw-tools.yaml`
  declara 7 candidatas Beta-1 (`read_file`, `list_dir`,
  `append_note`, `create_task`, `git_status`, `git_diff`,
  `run_tests`) con `enabled: false` y `default_state: disabled`.
- **Simulated tool execution** (`scripts/openclaw-simulate-tool.sh`,
  `watson tool simulate <name>` / `watson simtool <name>`) —
  ejercita la invocación de una tool sin ejecutarla; valida el
  registry, exige `enabled: false`, audita el intento
  (`tool_simulated`, `tool_unknown`, `tool_enabled_forbidden`).
- **Simulated execution binding** (`watson claw simulate-execute
  --mode <m> --tool <t> <plan>`) — corre toda la cadena de gates
  (kill switch, policy, plan exists, approval, tool registry) y
  termina en `Status: simulated-only`. 6 eventos auditados.
- **Execution manifests** — cada `simulate-execute` aprobado
  escribe `<workspace>/executions/<ts>-<tool>-manifest.md`
  inmutable con metadata, gates, plan reference, snapshot del
  contrato y `Result` que documenta la no-ejecución.
- **Execution manifest index/search** —
  `<workspace>/executions/index.tsv` (TSV append-only) +
  `watson ws execution-index / recent-executions /
  search-executions` para listado y búsqueda forense sin abrir
  cada `.md`.
- **Audit report consolidado**
  (`scripts/openclaw-report.sh`, `watson report`, `make report`)
  — markdown único que concatena policy/contracts/tools, últimos
  planes y ejecuciones simuladas, audit summary, readiness,
  negative tests, y conclusión con
  `ready_for_real_execution=no`. Acepta `--mode <m>` y
  `--out <archivo.md>`.

## No incluido

- **Ejecución real.** Ningún path de `claw execute` o
  `simulate-execute` invoca binarios externos.
- **Runtime real.** El motor que ejecuta herramientas no
  existe; `[BLOCKED] real execution runtime not implemented`
  es invariante esperada.
- **`sudo`** en runtime. `install.sh` lo pide explícito; ningún
  script de OpenClaw lo invoca.
- **Red.** No hay `curl`, `wget`, `ssh`, ni sockets en ningún
  path de runtime / instalación.
- **Plugins externos.** No se carga código fuera del repo.
- **Marketplace.** No hay distribución de tools externa.
- **Daemon agéntico.** Toda invocación es CLI síncrona.
- **Transporte TCP.** Sin servicios de red.
- **ISO `v0.4.0-alpha`** — el build queda como PR posterior
  (igual que en v0.3). Esta release prepara código + docs +
  preflight; el `.iso` y su `.sha256` se generan después.

## Próximo paso

Build ISO `v0.4.0-alpha` en PR aparte:

1. Build (`scripts/build-iso.sh` cuando esté listo).
2. Inspección squashfs.
3. QEMU smoke (boot + login + `watson version` + `watson doctor`).
4. SHA256 + GitHub release asset.
5. Git tag `v0.4.0-alpha`.

Ver [`V0.4_ALPHA_CHECKLIST.md`](V0.4_ALPHA_CHECKLIST.md) para
la lista exacta de validación obligatoria antes de tagear.
