#!/usr/bin/env bash
# ask-local.sh — Pregunta a Ollama (llama3.2:3b) usando docs/ como contexto.
# Uso: ./scripts/ask-local.sh "tu pregunta"

# 1) Validar que recibimos una pregunta.
if [ $# -eq 0 ]; then
    echo "Uso: ./scripts/ask-local.sh \"tu pregunta\""
    exit 1
fi

# 2) Verificar que Ollama está instalado.
if ! command -v ollama >/dev/null 2>&1; then
    echo "Error: Ollama no está instalado."
    echo "Instálalo con:  curl -fsSL https://ollama.com/install.sh | sh"
    echo "Luego descarga el modelo:  ollama pull llama3.2:3b"
    exit 1
fi

# Juntamos todos los argumentos como una sola pregunta.
pregunta="$*"

# 3) Resolver la carpeta de docs. Buscamos en este orden:
#      a. $PATRICK_OS_DOCS (override explícito).
#      b. ./docs desde el cwd actual (corriendo desde el repo).
#      c. ../docs relativo a este script (script invocado por path absoluto).
#      d. /usr/local/share/patrick-os/docs (instalación al sistema).
#    Si ninguna existe, seguimos pero sin contexto.
script_dir="$(cd "$(dirname "$0")" && pwd)"

if [ -n "$PATRICK_OS_DOCS" ] && [ -d "$PATRICK_OS_DOCS" ]; then
    PROJECT_DOCS_DIR="$PATRICK_OS_DOCS"
elif [ -d "./docs" ]; then
    PROJECT_DOCS_DIR="$(cd ./docs && pwd)"
elif [ -d "$script_dir/../docs" ]; then
    PROJECT_DOCS_DIR="$(cd "$script_dir/../docs" && pwd)"
elif [ -d "/usr/local/share/patrick-os/docs" ]; then
    PROJECT_DOCS_DIR="/usr/local/share/patrick-os/docs"
else
    PROJECT_DOCS_DIR=""
fi

# 4) Construir el contexto leyendo los documentos que existan.
contexto=""
if [ -n "$PROJECT_DOCS_DIR" ]; then
    echo "Contexto desde: $PROJECT_DOCS_DIR"
    for doc in "$PROJECT_DOCS_DIR/README.md" "$PROJECT_DOCS_DIR/ARCHITECTURE.md"; do
        if [ -f "$doc" ]; then
            contexto+=$'\n--- '"$(basename "$doc")"$' ---\n'
            contexto+="$(cat "$doc")"
            contexto+=$'\n'
        fi
    done
fi

if [ -z "$contexto" ]; then
    echo "Aviso: no se encontró README.md ni ARCHITECTURE.md en una ubicación conocida."
    echo "       La pregunta se enviará sin contexto del proyecto."
fi

# 5) Armar el prompt final.
prompt="Eres un asistente del proyecto PatrickOS. Usa el siguiente contexto cuando aplique.

Contexto del proyecto:
$contexto

Pregunta del usuario: $pregunta

Responde de forma clara, concisa y en español."

# 6) Enviar el prompt a Ollama por stdin.
echo "Consultando llama3.2:3b (puede tardar la primera vez)..."
echo
echo "$prompt" | ollama run llama3.2:3b
