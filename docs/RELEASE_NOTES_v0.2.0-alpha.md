# PatrickOS v0.2.0-alpha

## Enfoque

Esta versión mejora Watson como centro operativo local de PatrickOS.

## Nuevo desde v0.1.0-alpha

- Watson CLI directo desde terminal.
- Aliases rápidos.
- Notas rápidas locales.
- Tareas rápidas locales.
- Resumen diario local.
- Home dashboard local.
- OpenClaw stub seguro.
- Herramientas rápidas de desarrollo.
- Checks de permisos ejecutables para scripts.
- Contexto operativo del proyecto en docs/PROJECT_CONTEXT.md.
- Checklist v0.2.0-alpha en docs/V0.2_ALPHA_CHECKLIST.md.

## Comandos destacados

- watson h
- watson st
- watson ia
- watson ask "pregunta"
- watson nota "texto"
- watson tarea "texto"
- watson diario
- watson inicio
- watson claw
- make check

## Validación requerida

- make check
- watson inicio
- watson diario
- watson validar
- watson claw
- scripts/release-checklist.sh v0.2.0-alpha

## Limitaciones

- No incluye OpenClaw runtime real.
- No incluye NVIDIA propietario.
- No incluye Firefox, LibreOffice ni OBS.
- No se recomienda instalación en hardware real todavía.
- **ISO v0.2.0-alpha aún no construida en este PR.** Esta release prepara
  metadata, docs y checks; el build de ISO queda fuera del scope y se
  hará en un PR aparte una vez validado el checklist.

## Estado

Alpha funcional enfocada en utilidad diaria local. Código y docs listos;
ISO pendiente de construcción.
