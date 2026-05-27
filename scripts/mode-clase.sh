#!/usr/bin/env bash
# Modo clase de PatrickOS: workspace docente mínimo y listado.
# Sin LibreOffice ni IDEs pesadas: solo crea la carpeta y muestra el contenido.

WORKSPACE="$HOME/PatrickOS/workspaces/clase"

echo "Modo clase PatrickOS"
echo

mkdir -p "$WORKSPACE"
echo "Workspace: $WORKSPACE"
echo

echo "Contenido:"
if [ -n "$(ls -A "$WORKSPACE" 2>/dev/null)" ]; then
    ls -la "$WORKSPACE"
else
    echo "  (vacío — guarda aquí presentaciones, bibliografía y notas de clase)"
fi
