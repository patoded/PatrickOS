#!/usr/bin/env bash
# Modo IA de PatrickOS: muestra entorno (kernel, RAM, CPU), detecta WSL2 y
# revisa si Ollama y nvidia-smi están disponibles.
# Sin 'set -e': queremos ejecutar todas las comprobaciones aunque alguna falle.

echo "Modo IA PatrickOS"
echo

echo "Kernel (uname -a):"
uname -a
echo

echo "Memoria (free -h):"
if command -v free >/dev/null 2>&1; then
    free -h
else
    echo "  Aviso: 'free' no está disponible en este sistema."
fi
echo

echo "CPU (resumen de lscpu):"
if command -v lscpu >/dev/null 2>&1; then
    # Filtramos solo las líneas más relevantes para no llenar la pantalla.
    lscpu | grep -E "^(Architecture|CPU\(s\)|Model name|Vendor ID|CPU max MHz):"
else
    echo "  Aviso: 'lscpu' no está instalado (paquete: util-linux)."
fi
echo

echo "Entorno WSL2:"
if uname -a | grep -qi microsoft; then
    echo "  Detectado: estamos dentro de WSL2."
else
    echo "  No se detecta WSL2 (parece Linux nativo u otro entorno)."
fi
echo

echo "Ollama:"
if command -v ollama >/dev/null 2>&1; then
    echo "  Ollama encontrado en: $(command -v ollama)"
else
    echo "  Ollama no está instalado todavía."
fi
echo

echo "GPU NVIDIA:"
if command -v nvidia-smi >/dev/null 2>&1; then
    echo "  nvidia-smi encontrado en: $(command -v nvidia-smi)"
else
    echo "  NVIDIA no disponible desde este entorno."
fi
