# PatrickOS v0.4.0-alpha

## Estado

**Preliminar.** Watson reporta `v0.4.0-dev`; el bump a
`v0.4.0-alpha` se hace cuando el checklist correspondiente quede
en verde. v0.4 es un ciclo de **preparación de OpenClaw Beta-1**,
no de runtime real.

## En desarrollo

- OpenClaw Beta-1 planning (ver
  [`OPENCLAW_BETA1_PLAN.md`](OPENCLAW_BETA1_PLAN.md)).
- Tool contracts accionables (validador efectivo del schema en
  [`OPENCLAW_TOOL_CONTRACTS.md`](OPENCLAW_TOOL_CONTRACTS.md)).
- Allowlist concreta (primeras entradas candidatas en
  `configs/openclaw-tools.yaml`, todavía `state: disabled`).
- Negative tests (ver
  [`OPENCLAW_NEGATIVE_TESTS.md`](OPENCLAW_NEGATIVE_TESTS.md)).
- Sandbox design (bwrap / firejail / equivalente).
- Human confirmation gate por step.
- Simulated execution sobre el `blocked-by-design` actual.
- **Beta-1 readiness gate** (`scripts/openclaw-readiness.sh`,
  `watson readiness`, `make readiness`) — evalúa policy +
  contracts + tools + negative tests + doctor + execute gate +
  simulated binding y reporta `ready_for_simulated_beta1=yes` /
  `ready_for_real_execution=no` (este último es `[BLOCKED]` por
  diseño en Beta-0/v0.4).

## No incluido todavía

- Ejecución real libre.
- `sudo`.
- Red.
- Plugins externos.
- Marketplace.
- Daemon agéntico.
- Transporte TCP.
- **ISO `v0.4`** — el ciclo cierra código + docs; el build se
  decide después, como en v0.3.
