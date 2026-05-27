#!/usr/bin/env bash
# Modo consulta de PatrickOS: workspace clínico mínimo, plantilla SOAP, listado.
# Sin GUIs ni dependencias extra: solo crea carpeta, plantilla y muestra archivos.

WORKSPACE="$HOME/PatrickOS/workspaces/consulta"
PLANTILLA="$WORKSPACE/nota-soap.md"

echo "Modo consulta PatrickOS"
echo

# 1) Asegurar el workspace.
mkdir -p "$WORKSPACE"
echo "Workspace: $WORKSPACE"
echo

# 2) Crear plantilla SOAP la primera vez.
if [ ! -f "$PLANTILLA" ]; then
    cat > "$PLANTILLA" <<'EOF'
# Nota SOAP

Fecha:
Paciente:

## S - Subjetivo


## O - Objetivo


## A - Análisis


## P - Plan

EOF
    echo "Plantilla SOAP creada: $PLANTILLA"
else
    echo "Plantilla SOAP ya existe: $PLANTILLA"
fi
echo

# 3) Listar lo que haya (máx 10, ordenado por mtime).
echo "Archivos recientes:"
if [ -n "$(ls -A "$WORKSPACE" 2>/dev/null)" ]; then
    ls -lt "$WORKSPACE" | tail -n +2 | head -10
else
    echo "  (workspace vacío)"
fi
