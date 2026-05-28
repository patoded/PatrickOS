# PatrickOS v0.1.0-alpha

Primera versión Alpha funcional de PatrickOS.

## Validado

- ISO live basada en Ubuntu 24.04.
- Arranque funcional en QEMU.
- Escritorio XFCE funcional.
- Watson CLI instalado globalmente.
- Watson responde en:
  - estado
  - modo desarrollo
  - modo ia
- zram activo.
- Teclado latinoamericano funcional en entorno gráfico.
- Build final empaquetado con grub-mkrescue.
- Perfil workstation inicial para multitarea.

## Limitaciones conocidas

- Versión Alpha experimental.
- Probada en QEMU, no en hardware real.
- No incluye drivers NVIDIA propietarios.
- No incluye OpenClaw runtime.
- No incluye Firefox, LibreOffice ni OBS.
- Ollama no viene instalado dentro de la ISO en esta Alpha.

## Uso recomendado

```bash
qemu-system-x86_64 \
  -m 4096 \
  -smp 2 \
  -cdrom patrick-os-alpha.iso \
  -boot d
