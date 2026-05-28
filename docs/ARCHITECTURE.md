# Arquitectura PatrickOS / WatsonOS

## Objetivo

Crear una estación de trabajo Linux personalizada, ligera y reproducible, optimizada para ASUS TUF con NVIDIA, productividad médica, desarrollo, IA local y automatización mediante Watson.

## Capas principales

### 1. Sistema base

- Ubuntu/WSL2 para desarrollo inicial.
- Debian/Ubuntu como base futura de ISO.
- XFCE como escritorio ligero.
- Soporte para NVIDIA, CUDA, Bluetooth e impresión.

### 2. Entorno de desarrollo

- Git
- Python
- Node.js
- Docker
- live-build
- VS Code
- Claude/Opus como copiloto de desarrollo

### 3. Watson Core

Watson será el agente local del sistema.

Funciones iniciales:

- Ejecutar comandos seguros.
- Lanzar modos de trabajo.
- Abrir herramientas.
- Automatizar tareas repetitivas.
- Preparar entorno de consulta, clase, video, desarrollo e IA.

### 4. Watson Vision

Módulo futuro para permitir, con autorización explícita:

- Ver pantalla.
- Analizar errores visuales.
- Leer ventanas.
- Usar cámara.
- Analizar entorno físico.

### 5. Seguridad

Reglas iniciales:

- Watson no ejecuta acciones peligrosas sin confirmación.
- No acceso permanente a pantalla, cámara o micrófono.
- Logs de acciones importantes.
- Separación entre comandos seguros y comandos sensibles.

## Workstation Profile

PatrickOS Alpha está afinado para un flujo de trabajo concreto: muchas
ventanas abiertas en paralelo (navegador, VS Code, varias terminales,
documentación, IA local), cambio rápido entre ellas, copiar/pegar
constante. Las decisiones siguientes se toman *en contra* de los defaults
"bonitos" de XFCE a propósito.

### Prioridades

1. **Simplicidad** — menos piezas que puedan fallar.
2. **Velocidad** — latencia baja al cambiar ventana o pegar texto.
3. **Bajo consumo** — útil en laptops y al correr modelos locales.
4. **Copiar/pegar confiable** — historial persistente vía clipman + acceso
   por CLI con `xclip`/`xsel` para scripts y Watson.
5. **Cambio rápido entre ventanas** — workspaces direccionados por número,
   tiling por flechas.
6. **Cero efectos innecesarios** — sin animaciones, sin splash, sin
   shadows, sin transiciones.

### Qué está *apagado* a propósito

| Cosa | Estado | Por qué |
|------|--------|---------|
| Compositor xfwm4 | off | tearing irrelevante en QEMU/laptop; reduce uso de GPU y latencia |
| Animaciones GTK (`Net/EnableAnimations`) | off | apps que se sienten instantáneas |
| Plymouth splash | off (desde PR #4) | el splash escondía hangs reales del boot |
| `xfce4-session` splash | off | medio segundo de login que no aporta nada |
| Sonidos de UI | off | ruido innecesario |
| Indexadores tipo tracker/baloo | no instalados | consumo de I/O constante que no necesitamos |

### Atajos (Super = tecla Windows)

| Atajo | Acción |
|-------|--------|
| `Super+Enter` | xfce4-terminal |
| `Super+Space` | rofi (launcher) |
| `Super+E` | thunar (gestor de archivos) |
| `Super+1..4` | ir a workspace 1..4 |
| `Super+Shift+1..4` | mover ventana actual a workspace 1..4 |
| `Super+Left/Right/Up/Down` | tile a ese borde |
| `Alt+Tab` | ciclo normal de ventanas (default XFCE) |

### Memoria: zram

`zram-tools` se instala y habilita en build (`hook
0020-workstation-tweaks`). Crea swap comprimida en RAM, que en cargas
multitarea con muchos procesos GTK y modelos locales reduce presión sobre
el disco sin gastar swap real. Tunear en `/etc/default/zramswap` si hace
falta.

### Dónde vive todo esto en el repo

- Paquetes: `iso/config/package-lists/patrick-os.list.chroot`.
- Defaults XFCE: `iso/config/includes.chroot/etc/skel/.config/xfce4/xfconf/xfce-perchannel-xml/*.xml`.
  Solo declaramos lo que cambiamos respecto al default; el resto se
  hereda del sistema. Se copian a `~/.config/...` la primera vez que el
  usuario live entra a su sesión.
- Habilitación de servicios ligeros: `iso/config/hooks/normal/0020-workstation-tweaks.hook.chroot`.
- Autostart de clipman: lo trae el paquete `xfce4-clipman-plugin` en
  `/etc/xdg/autostart/`, no lo duplicamos.

### Keyboard Compatibility Layer

- **Prioridad**: escritura fluida de comandos. Si `=`, `-`, `_`, `:`, `/`
  o las comillas no salen donde se esperan, todo lo demás del Alpha se
  cae (terminal, Watson, edición de archivos).
- **Layout inicial**: `latam` (Spanish Latin American), aplicado a TTY,
  consola y X11/XFCE desde el primer boot. No requiere intervención del
  usuario.
- **Objetivo**: evitar fricción al copiar/pegar y al usar terminal en
  QEMU o en metal. El layout en GUI coincide con el de consola, así que
  no hay sorpresa al alternar entre xfce4-terminal y un TTY.

Implementación: hook `0030-keyboard-locale.hook.chroot` escribe
`/etc/default/keyboard`, e `includes.chroot/etc/X11/xorg.conf.d/00-keyboard.conf`
lo refuerza en Xorg. Si en el futuro hace falta soportar varios
layouts conmutables, ese es el lugar para añadir `XKBOPTIONS="grp:..."`.
Cambiar en runtime: `setxkbmap latam`.

### Qué NO entra en este perfil

GNOME, KDE, LibreOffice, OBS, drivers NVIDIA, OpenClaw, y por ahora
tampoco Firefox. Cada uno tiene su PR o se rechaza explícitamente. El
objetivo Alpha es una base ligera y verificable, no un escritorio
completo.

## Modos de trabajo iniciales

### Modo consulta

- Abrir notas clínicas.
- Preparar plantilla SOAP.
- Abrir calculadoras geriátricas.
- Preparar transcripción.

### Modo clase

- Abrir documentos docentes.
- Preparar bibliografía.
- Abrir presentaciones.
- Activar herramientas de diseño.

### Modo video

- Abrir guiones.
- Abrir editor.
- Preparar carpetas multimedia.
- Activar ffmpeg/transcripción.

### Modo desarrollo

- Abrir VS Code.
- Preparar terminal.
- Activar Git.
- Abrir proyecto PatrickOS.

### Modo IA

- Activar Ollama.
- Verificar GPU.
- Cargar modelo local.
- Monitorear recursos.
- Ollama instalado en WSL2.
- NVIDIA detectada por Ollama.
- API local disponible en 127.0.0.1:11434.
