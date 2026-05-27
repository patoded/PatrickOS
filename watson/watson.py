#!/usr/bin/env python3
import os
import pathlib
import subprocess

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


def mostrar_menu():
    print("\nWatson - Agente local PatrickOS")
    print("Comandos disponibles:")
    print("  modo consulta")
    print("  modo clase")
    print("  modo video")
    print("  modo desarrollo")
    print("  modo ia")
    print("  preguntar ia")
    print("  estado")
    print("  salir")


def ejecutar_comando(comando):
    comando = comando.strip().lower()

    if comando == "modo consulta":
        print("Activando modo consulta...")
        print("Prepararía notas clínicas, plantilla SOAP y herramientas geriátricas.")

    elif comando == "modo clase":
        print("Activando modo clase...")
        print("Prepararía documentos docentes, bibliografía y presentaciones.")

    elif comando == "modo video":
        print("Activando modo video...")
        print("Prepararía guiones, editor, OBS, ffmpeg y carpeta multimedia.")

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

    elif comando == "salir":
        print("Cerrando Watson.")
        return False

    else:
        print("Comando no reconocido.")

    return True


def main():
    mostrar_menu()

    activo = True
    while activo:
        comando = input("\nwatson> ")
        activo = ejecutar_comando(comando)


if __name__ == "__main__":
    main()
