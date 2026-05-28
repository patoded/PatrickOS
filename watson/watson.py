#!/usr/bin/env python3
import os
import pathlib
import subprocess
import sys

_VERSION = "v0.2.0-dev"

# Resolución de la carpeta de scripts:
#   1. PATRICK_OS_SCRIPTS (override en tiempo de ejecución, ej. instalación al sistema)
#   2. ../scripts relativo a este archivo (modo repositorio)
_DEFAULT_SCRIPTS_DIR = pathlib.Path(__file__).resolve().parent.parent / "scripts"
SCRIPTS_DIR = pathlib.Path(os.environ.get("PATRICK_OS_SCRIPTS", str(_DEFAULT_SCRIPTS_DIR)))


def ejecutar_seguro(cmd, descripcion):
    # Ejecuta un comando externo y reporta errores sin tumbar a Watson.
    print(f"\n[{descripcion}] $ {' '.join(cmd)}")
    try:
        subprocess.run(cmd, check=True)
    except FileNotFoundError:
        print(f"  Error: '{cmd[0]}' no está instalado o no se encuentra en el PATH.")
    except PermissionError:
        print(f"  Error: no tengo permisos para ejecutar '{cmd[0]}'. Revisa chmod +x o permisos del archivo.")
    except subprocess.CalledProcessError as e:
        print(f"  Error: '{cmd[0]}' terminó con código {e.returncode}.")


def mostrar_ayuda():
    print("\nWatson - Agente local PatrickOS")
    print("Comandos disponibles:")
    print("  ayuda                  esta lista")
    print("  version                versión de Watson/PatrickOS")
    print("  estado                 estado básico de Watson")
    print("  sistema                diagnóstico (uname, free, lscpu, swap, df)")
    print("  validar                corre validate-system.sh (OK/WARN/FAIL)")
    print("  release                corre release-checklist.sh")
    print("  modo consulta          flujo clínico")
    print("  modo clase             flujo docente")
    print("  modo video             flujo de edición")
    print("  modo desarrollo        entorno dev")
    print("  modo ia                chequea Ollama/GPU")
    print("  preguntar ia           pregunta a Ollama con contexto local")
    print("  salir                  cierra el menú interactivo")
    print("\nEjemplos:")
    print("  watson validar")
    print("  watson sistema")
    print("  watson modo desarrollo")


def mostrar_version():
    print("PatrickOS Alpha")
    print("Watson CLI")
    print(f"versión actual: {_VERSION}")


def mostrar_sistema():
    print("Diagnóstico de sistema PatrickOS")
    ejecutar_seguro(["uname", "-a"], "uname")
    ejecutar_seguro(["free", "-h"], "memoria")
    ejecutar_seguro(["lscpu"], "cpu")
    ejecutar_seguro(["swapon", "--show"], "swap")
    ejecutar_seguro(["df", "-h", "/"], "disco")


def ejecutar_comando(comando):
    comando = comando.strip().lower()

    if comando == "modo consulta":
        print("Activando modo consulta...")
        ejecutar_seguro([str(SCRIPTS_DIR / "mode-consulta.sh")], "mode-consulta.sh")

    elif comando == "modo clase":
        print("Activando modo clase...")
        ejecutar_seguro([str(SCRIPTS_DIR / "mode-clase.sh")], "mode-clase.sh")

    elif comando == "modo video":
        print("Activando modo video...")
        ejecutar_seguro([str(SCRIPTS_DIR / "mode-video.sh")], "mode-video.sh")

    elif comando == "modo desarrollo":
        print("Activando modo desarrollo...")
        ejecutar_seguro([str(SCRIPTS_DIR / "mode-dev.sh")], "mode-dev.sh")

    elif comando == "modo ia":
        print("Activando modo IA...")
        ejecutar_seguro([str(SCRIPTS_DIR / "mode-ai.sh")], "mode-ai.sh")

    elif comando == "preguntar ia":
        pregunta = input("Tu pregunta: ").strip()
        if not pregunta:
            print("No se recibió pregunta. Cancelando.")
        else:
            ejecutar_seguro([str(SCRIPTS_DIR / "ask-local.sh"), pregunta], "ask-local.sh")

    elif comando == "estado":
        print("Watson activo. Sistema base en modo desarrollo.")

    elif comando == "ayuda":
        mostrar_ayuda()

    elif comando == "version":
        mostrar_version()

    elif comando == "sistema":
        mostrar_sistema()

    elif comando == "validar":
        ejecutar_seguro([str(SCRIPTS_DIR / "validate-system.sh")], "validate-system.sh")

    elif comando == "release":
        ejecutar_seguro([str(SCRIPTS_DIR / "release-checklist.sh")], "release-checklist.sh")

    elif comando == "salir":
        print("Cerrando Watson.")
        return False

    else:
        print("Comando no reconocido.")

    return True


def main():
    # Modo no interactivo: si hay argumentos, los tratamos como un comando único
    # y salimos. Útil para hooks, .desktop entries y scripts.
    #   watson modo desarrollo
    #   watson preguntar ia
    if len(sys.argv) > 1:
        ejecutar_comando(" ".join(sys.argv[1:]))
        return

    # Modo interactivo: menú con prompt.
    mostrar_ayuda()
    activo = True
    while activo:
        comando = input("\nwatson> ")
        activo = ejecutar_comando(comando)


if __name__ == "__main__":
    main()
