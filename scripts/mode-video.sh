#!/usr/bin/env bash
# Modo video de PatrickOS: workspace multimedia + verificación de herramientas.
# No lanza OBS ni nada pesado: solo reporta si ffmpeg y obs existen.

WORKSPACE="$HOME/PatrickOS/workspaces/video"

echo "Modo video PatrickOS"
echo

mkdir -p "$WORKSPACE"
echo "Workspace: $WORKSPACE"
echo

echo "ffmpeg:"
if command -v ffmpeg >/dev/null 2>&1; then
    echo "  Encontrado en: $(command -v ffmpeg)"
    ffmpeg -version 2>/dev/null | head -1
else
    echo "  Aviso: ffmpeg no está instalado. Instálalo con: sudo apt install ffmpeg"
fi
echo

echo "OBS Studio:"
if command -v obs >/dev/null 2>&1; then
    echo "  Encontrado en: $(command -v obs)"
else
    echo "  Aviso: OBS no detectado (opcional). Instálalo con: sudo apt install obs-studio"
fi
