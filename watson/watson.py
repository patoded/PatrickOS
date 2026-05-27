#!/usr/bin/env python3

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
        print("Prepararía VS Code, Git, terminal y proyecto PatrickOS.")

    elif comando == "modo ia":
        print("Activando modo IA...")
        print("Prepararía Ollama, GPU, modelos locales y monitoreo.")

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
