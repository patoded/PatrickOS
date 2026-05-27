# Instalar PatrickOS Alpha

PatrickOS Alpha se distribuye como una ISO live booteable. No requiere
instalación a disco para probarse — arranca, entrega un escritorio XFCE con
Watson y Ollama, y vuelve al estado limpio al apagar.

## 1. Construir la ISO

```bash
sudo apt install live-build
sudo bash iso/build.sh
```

El resultado queda en `iso/patrick-os-alpha.iso`. La build toma 20-40
minutos y necesita ~10 GB libres en `/`.

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

Al arrancar:

- Login automático como usuario `user` (sin contraseña, modo live).
- Escritorio XFCE.
- `watson` disponible en PATH → `watson` (menú) o `watson modo desarrollo`.
- `ollama` disponible en PATH → `ollama --version`, `ollama pull llama3.2:3b`.

## 3. Verificación mínima dentro de la VM

Abre una terminal en el escritorio y ejecuta:

```bash
watson modo ia
ollama --version
```

`modo ia` debe reportar Ollama presente y NVIDIA ausente (esperado en QEMU
sin GPU passthrough).
