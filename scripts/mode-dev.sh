#!/usr/bin/env bash
# Modo desarrollo de PatrickOS: muestra ruta, estado de git y árbol del proyecto.
# No usamos 'set -e' a propósito: queremos seguir ejecutando aunque un comando falle.

echo "Modo desarrollo PatrickOS"
echo

echo "Ruta actual:"
pwd
echo

echo "git status:"
if ! git status; then
    echo "  Aviso: git status falló (¿estás fuera de un repositorio?)."
fi
echo

echo "tree -L 2:"
if command -v tree >/dev/null 2>&1; then
    tree -L 2
else
    echo "  Aviso: 'tree' no está instalado. Instálalo con: sudo apt install tree"
fi
