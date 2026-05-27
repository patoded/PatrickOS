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

# 3) Resolver rutas relativas al script (funciona desde cualquier directorio).
script_dir="$(cd "$(dirname "$0")" && pwd)"
proyecto_dir="$(dirname "$script_dir")"

# 4) Construir el contexto leyendo los documentos que existan.
contexto=""
for doc in "$proyecto_dir/docs/README.md" "$proyecto_dir/docs/ARCHITECTURE.md"; do
    if [ -f "$doc" ]; then
        contexto+=$'\n--- '"$(basename "$doc")"$' ---\n'
        contexto+="$(cat "$doc")"
        contexto+=$'\n'
    fi
done

if [ -z "$contexto" ]; then
    echo "Aviso: no se encontró docs/README.md ni docs/ARCHITECTURE.md."
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
