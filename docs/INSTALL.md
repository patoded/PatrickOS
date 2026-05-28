# Instalar PatrickOS Alpha

PatrickOS Alpha se distribuye como una ISO live booteable. No requiere
instalación a disco para probarse — arranca, entrega una shell o (cuando el
hardware lo permite) un escritorio XFCE con Watson y Ollama, y vuelve al
estado limpio al apagar.

> **Alcance Alpha**: el objetivo es *boot confiable a TTY o escritorio
> mínimo y validar Watson*. El escritorio pulido y el branding entran en
> PRs posteriores; no son requisito de este Alpha.

## 1. Construir la ISO

```bash
sudo apt install live-build grub-common grub-pc-bin xorriso
sudo bash iso/build.sh
```

El resultado queda en `iso/patrick-os-alpha.iso`. La build toma 20-40
minutos y necesita ~10 GB libres en `/`.

El último paso (`[7/7]`) reescribe `binary/boot/grub/grub.cfg` y rearma la
ISO con `grub-mkrescue` — ese es el generador final, no la ISO transitoria
que produce `lb build` internamente.

**Aviso WSL2**: `live-build` dentro de WSL2 puede fallar por limitaciones de
cgroups, mount o `binfmt_misc`. Si lo intentas y la build se rompe, las
opciones son: (a) construir en una VM Linux nativa, (b) usar un contenedor
Docker privilegiado con loopback habilitado, o (c) un host bare-metal.

## 2. Probar la ISO en QEMU

```bash
sudo apt install qemu-system-x86
qemu-system-x86_64 \
    -m 4096 \
    -smp 2 \
    -enable-kvm \
    -cdrom iso/patrick-os-alpha.iso \
    -boot d
```

Si no tienes KVM disponible (por ejemplo, virtualización anidada
deshabilitada), omite `-enable-kvm`. Será más lento pero arranca igual.

## 3. Menú GRUB

Al arrancar verás tres entradas:

1. **PatrickOS Alpha (live)** — arranque normal con `nomodeset`. Intenta
   levantar LightDM/XFCE. Es la opción por defecto.
2. **PatrickOS Alpha (live, fail-safe)** — mismo arranque con flags
   conservadoras (`noapic`, `nolapic`, `vga=normal`, etc.). Útil si la
   opción 1 se cuelga.
3. **PatrickOS Alpha terminal mode** — arranca a `multi-user.target` (sin
   X, sin LightDM). Llega a una TTY de root/usuario live directamente. Es
   la opción **recomendada para validar Watson** durante el Alpha porque
   no depende del stack gráfico.

> **Nota**: el splash de Plymouth (`quiet splash`) está deshabilitado a
> propósito en este Alpha. Verás los mensajes del kernel durante el boot;
> eso es esperado y ayuda a diagnosticar si algo se atora.

## 4. Validación mínima de Watson (terminal mode)

Elige **PatrickOS Alpha terminal mode** en el menú GRUB. Cuando llegues
al prompt, ejecuta:

```bash
which watson
watson estado
watson modo desarrollo
```

Resultados esperados:

- `which watson` → `/usr/local/bin/watson`.
- `watson estado` → reporta presencia de Ollama y diagnóstico básico.
- `watson modo desarrollo` → entra al flujo de modo desarrollo de Watson.

Con eso queda validada la integración Watson en la ISO Alpha. Si los tres
comandos responden sin error, el Alpha está cumplido para esta iteración.

## 5. Teclado (Latin American Spanish por default)

PatrickOS Alpha arranca con layout **latam** (Spanish Latin American) en
consola y XFCE. Es el layout que coincide con el teclado físico ES-LA
que se usa desde Windows, así que `= / - _ : ; " '` y demás caracteres
salen donde se esperan.

Implementación en el repo:

- `iso/config/hooks/normal/0030-keyboard-locale.hook.chroot` escribe
  `/etc/default/keyboard` con `XKBLAYOUT="latam"`.
- `iso/config/includes.chroot/etc/X11/xorg.conf.d/00-keyboard.conf`
  refuerza el layout dentro de Xorg.

### Si QEMU sigue mostrando caracteres raros

QEMU traduce scancodes según su propio `-k`. Si tu host es Windows con
teclado ES-LA y aun así ves layout 'us' dentro de la VM, lanza QEMU con:

```bash
qemu-system-x86_64 \
    -m 4096 -smp 2 -enable-kvm \
    -k es \
    -cdrom iso/patrick-os-alpha.iso -boot d
```

`-k es` no es exacto a latam pero cubre casi todos los símbolos que
suelen romperse. Para una correspondencia 1:1 perfecta, pasa el teclado
físico por USB passthrough (`-device usb-host,...`) en lugar de depender
del mapeo de QEMU.

### Cambiar el layout temporalmente dentro de la sesión

```bash
setxkbmap latam        # X11 / XFCE
sudo loadkeys la-latin1  # TTY (opcional)
```

Para hacerlo persistente entre boots, editar `/etc/default/keyboard` y
ejecutar `sudo setupcon`.

### Verificar el layout actual

```bash
setxkbmap -query           # qué tiene Xorg cargado ahora mismo
cat /etc/default/keyboard  # qué dice el archivo de sistema
localectl status           # vista combinada (systemd)
```

Los tres deberían mostrar `latam` después de un boot limpio.

## 6. (Opcional) Verificar modo gráfico

Si el menú 1 levanta el escritorio XFCE, también puedes correr:

```bash
watson modo ia
ollama --version
```

`modo ia` debe reportar Ollama presente y NVIDIA ausente (esperado en
QEMU sin GPU passthrough). Si el escritorio no levanta y solo ves el
splash o un cursor parpadeando, vuelve a GRUB y usa **terminal mode** —
es el camino soportado en este Alpha.
