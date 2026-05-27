#!/usr/bin/env python3
import subprocess


def ejecutar_seguro(cmd, descripcion):
    # Ejecuta un comando externo y reporta errores sin tumbar a Watson.
    print(f"\n[{descripcion}] $ {' '.join(cmd)}")
    try:
        subprocess.run(cmd, check=True)
    except FileNotFoundError:
        print(f"  Error: '{cmd[0]}' no está instalado o no se encuentra en el PATH.")
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
        ejecutar_seguro(["./scripts/mode-dev.sh"], "mode-dev.sh")

    elif comando == "modo ia":
        print("Activando modo IA...")
        ejecutar_seguro(["./scripts/mode-ai.sh"], "mode-ai.sh")

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
