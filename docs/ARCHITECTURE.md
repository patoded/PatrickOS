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
