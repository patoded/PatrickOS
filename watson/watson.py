#!/usr/bin/env python3
import os
import pathlib
import subprocess
import sys

_VERSION = "v0.3.0-dev"

# Aliases cortos → forma canónica. Normalizamos una sola vez al entrar a
# ejecutar_comando, así el dispatcher de abajo no necesita duplicar ramas
# por cada atajo. Si un alias debe llevar payload (caso "ask <texto>"),
# main() lo trata aparte para preservar el texto sin lowercaseo.
_ALIAS_MAP = {
    "h": "ayuda",
    "help": "ayuda",
    "v": "version",
    "ver": "version",
    "st": "estado",
    "sys": "sistema",
    "val": "validar",
    "rel": "release",
    "dev": "modo desarrollo",
    "ia": "modo ia",
    "ask": "preguntar ia",
    "claw": "openclaw",
    "ws": "workspace",
    "doc": "doctor",
    "pol": "policy",
    "aud": "audit",
    "tls": "tools",
    "n": "nota",
    "ns": "notas",
    "note": "nota",
    "notes": "notas",
    "t": "tarea",
    "ts": "tareas",
    "todo": "tarea",
    "todos": "tareas",
    "d": "diario",
    "daily": "diario",
    "i": "inicio",
    "home": "inicio",
    "panel": "inicio",
    "q": "salir",
    "exit": "salir",
    "quit": "salir",
}

# Prefijos que aceptan un texto libre como payload tras el primer token.
# Se chequean en main() ANTES de lowercasear el resto, así la pregunta o
# la nota mantienen mayúsculas/acentos/comillas tal cual el usuario las
# tipeó. Listamos formas canónicas y aliases cortos; ejecutar_comando
# normaliza el primer token vía _ALIAS_MAP, así no duplicamos dispatch.
_PAYLOAD_PREFIXES = (
    "preguntar ia",
    "workspace",
    "openclaw",
    "doctor",
    "policy",
    "audit",
    "tools",
    "note",
    "nota",
    "todo",
    "tarea",
    "claw",
    "ask",
    "doc",
    "pol",
    "aud",
    "tls",
    "ws",
    "n",
    "t",
)

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
    print("Comandos disponibles (alias entre paréntesis):")
    print("  ayuda (h, help)            esta lista")
    print("  version (v, ver)           versión de Watson/PatrickOS")
    print("  estado (st)                estado básico de Watson")
    print("  sistema (sys)              diagnóstico (uname, free, lscpu, swap, df)")
    print("  validar (val)              corre validate-system.sh (OK/WARN/FAIL)")
    print("  release (rel)              corre release-checklist.sh")
    print("  openclaw (claw)            status del runtime (Beta-0 dry-run)")
    print("  claw run \"tarea\"           plan dry-run (sin ejecutar nada)")
    print("  claw run --mode <m> \"...\"  dry-run en workspace por modo")
    print("  claw run --tag <t> --priority <p> \"...\"  metadata opcional del plan")
    print("  claw execute --mode <m> <file>  Beta-0 execution gate (siempre blocked-by-design)")
    print("  workspace list (ws)        lista workspaces locales por modo")
    print("  workspace init <modo>      crea workspace + README local")
    print("  workspace clean <m> --yes  vacía workspace (requiere --yes)")
    print("  workspace path <modo>      imprime ruta absoluta del workspace")
    print("  workspace plans <modo>     lista planes dry-run históricos del workspace")
    print("  workspace last-plan <modo> imprime el último plan dry-run")
    print("  workspace show-plan <m> <f> imprime un plan (f=latest o basename de plans/)")
    print("  workspace plan-index <modo> imprime plans/index.tsv (timestamp/mode/file/task)")
    print("  workspace recent <m> [n]   últimos n planes (default 5) — timestamp|file|task")
    print("  workspace search <m> <txt> busca planes por texto (case-insensitive)")
    print("  workspace filter-tag <m> <tag>          planes con tag exacto")
    print("  workspace filter-priority <m> <p>       planes con priority low/normal/high")
    print("  workspace approve-plan <m> <file>       marca plan local como approved")
    print("  workspace reject-plan <m> <f> [razón]   marca plan local como rejected")
    print("  workspace plan-status <m> <file>        imprime estado del plan (pending si no hay sidecar)")
    print("  nota \"texto\" (n, note)     guarda nota rápida local")
    print("  notas (ns, notes)          lista las últimas 20 notas")
    print("  tarea \"texto\" (t, todo)    agrega tarea pendiente")
    print("  tarea done <n>             marca tarea n como completada")
    print("  tareas (ts, todos)         lista últimas 30 tareas")
    print("  diario (d, daily)          resumen del día (notas + tareas)")
    print("  inicio (i, home, panel)    panel rápido WatsonOS (estado + daily + atajos)")
    print("  doctor (doc)               diagnóstico integral (repo + global + smokes)")
    print("  doctor repair              diagnóstico + sudo install + re-check")
    print("  policy (pol)               muestra/valida configs/openclaw-policy.yaml")
    print("  policy check               valida invariantes seguras (red/sudo/plugins/...)")
    print("  claw policy                idem, vía openclaw-stub")
    print("  claw kill [\"razón\"]        activa kill switch local (bloquea claw run)")
    print("  claw unkill                desactiva el kill switch")
    print("  claw status                muestra estado del runtime + kill switch")
    print("  audit (aud) [list|tail|path] lectura del audit log estructurado de OpenClaw")
    print("  tools (tls) [list|show|path] viewer del registry de herramientas (Beta-0: vacío)")
    print("  modo consulta              flujo clínico")
    print("  modo clase                 flujo docente")
    print("  modo video                 flujo de edición")
    print("  modo desarrollo (dev)      entorno dev")
    print("  modo ia (ia)               chequea Ollama/GPU")
    print("  preguntar ia (ask)         pregunta a Ollama con contexto local")
    print("  salir (q, exit, quit)      cierra el menú interactivo")
    print("\nEjemplos:")
    print("  watson val")
    print("  watson ask \"resume PatrickOS\"")
    print("  watson dev")
    print("  watson claw run \"prepara un plan\"")
    print("  watson ws list")
    print("  watson ws init desarrollo")
    print("  watson ws path desarrollo")
    print("  watson ws plans desarrollo")
    print("  watson ws last-plan desarrollo")
    print("  watson ws show-plan desarrollo latest")
    print("  watson ws plan-index desarrollo")
    print("  watson ws recent desarrollo")
    print("  watson ws search desarrollo \"clase\"")
    print("  watson ws filter-tag desarrollo clase")
    print("  watson ws filter-priority desarrollo high")
    print("  watson claw run --tag clase --priority high \"preparar clase\"")
    print("  watson ws approve-plan desarrollo 20260530-130934-plan.md")
    print("  watson ws plan-status desarrollo 20260530-130934-plan.md")
    print("  watson claw execute --mode desarrollo 20260530-130934-plan.md")
    print("  watson doctor")
    print("  watson doctor repair")
    print("  watson policy check")
    print("  watson claw kill \"pausa de seguridad\"")
    print("  watson claw unkill")
    print("  watson audit tail")
    print("  watson tools list")


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


def ejecutar_comando(comando, pregunta=None):
    # 'pregunta' es payload opcional; hoy solo lo usa "preguntar ia" cuando
    # el usuario pasa la pregunta por argv y no la queremos lowercasear ni
    # pedirla por input(). Mantener el mismo dispatcher para no duplicar.
    comando = comando.strip().lower()
    comando = _ALIAS_MAP.get(comando, comando)

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
        if pregunta is None:
            pregunta = input("Tu pregunta: ")
        pregunta = pregunta.strip()
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

    elif comando == "openclaw":
        # Beta-0 dry-run: sin payload = status (compatibilidad con el
        # stub original); con payload = "run [...]" se delega tal cual
        # al script, que parsea --mode y tarea. Splitting simple por
        # espacios es suficiente: el script rejunta la tarea con los
        # args sobrantes, así "plan para clase" llega completo.
        script = str(SCRIPTS_DIR / "openclaw-stub.sh")
        if pregunta is None or not pregunta.strip():
            ejecutar_seguro([script], "openclaw-stub.sh")
        else:
            args = pregunta.split()
            ejecutar_seguro([script, *args], f"openclaw-stub.sh {args[0]}")

    elif comando == "audit":
        # Lectura del audit log estructurado de OpenClaw. Sin args =
        # tail (las últimas 20 entradas); con args ('list', 'tail',
        # 'path') se forwardea al script.
        script = str(SCRIPTS_DIR / "openclaw-audit.sh")
        if pregunta is None or not pregunta.strip():
            ejecutar_seguro([script, "tail"], "openclaw-audit.sh tail")
        else:
            args = pregunta.split()
            ejecutar_seguro([script, *args], f"openclaw-audit.sh {args[0]}")

    elif comando == "tools":
        # Viewer read-only del tool registry. Sin args = list ('Beta-0
        # no hay herramientas'); con args ('path', 'show', 'list') se
        # forwardea al script. NO ejecuta herramientas.
        script = str(SCRIPTS_DIR / "openclaw-tools.sh")
        if pregunta is None or not pregunta.strip():
            ejecutar_seguro([script, "list"], "openclaw-tools.sh list")
        else:
            args = pregunta.split()
            ejecutar_seguro([script, *args], f"openclaw-tools.sh {args[0]}")

    elif comando == "policy":
        # Capa de policy local de OpenClaw. Sin args = show (lectura
        # rápida de qué tenemos); con args ('show', 'path', 'check')
        # se forwardean al script. 'check' es el gate que usa
        # openclaw-stub.sh antes de cada run.
        script = str(SCRIPTS_DIR / "openclaw-policy.sh")
        if pregunta is None or not pregunta.strip():
            ejecutar_seguro([script, "show"], "openclaw-policy.sh show")
        else:
            args = pregunta.split()
            ejecutar_seguro([script, *args], f"openclaw-policy.sh {args[0]}")

    elif comando == "doctor":
        # Sin payload = diagnóstico puro. Con payload ("repair" /
        # "--repair") se forwardea al script, que valida el subcomando
        # y dispara el flujo de reparación (sudo install + re-check).
        # Sólo el subcomando 'repair' usa sudo; el default no.
        script = str(SCRIPTS_DIR / "doctor.sh")
        if pregunta is None or not pregunta.strip():
            ejecutar_seguro([script], "doctor.sh")
        else:
            args = pregunta.split()
            ejecutar_seguro([script, *args], f"doctor.sh {args[0]}")

    elif comando == "workspace":
        # workspace.sh: list / init / clean / path. Mismo patrón que
        # openclaw: split por espacios y pasar al script, que valida
        # subcomando, modo y flags (--yes en clean).
        script = str(SCRIPTS_DIR / "workspace.sh")
        if pregunta is None or not pregunta.strip():
            ejecutar_seguro([script], "workspace.sh")
        else:
            args = pregunta.split()
            ejecutar_seguro([script, *args], f"workspace.sh {args[0]}")

    elif comando == "nota":
        if pregunta is None or not pregunta.strip():
            print("Uso: watson nota \"texto de la nota\"")
        else:
            ejecutar_seguro(
                [str(SCRIPTS_DIR / "notes.sh"), "add", pregunta],
                "notes.sh add",
            )

    elif comando == "notas":
        ejecutar_seguro([str(SCRIPTS_DIR / "notes.sh"), "list"], "notes.sh list")

    elif comando == "tarea":
        if pregunta is None or not pregunta.strip():
            print("Uso: watson tarea \"texto\"  |  watson tarea done <n>")
        else:
            p = pregunta.strip()
            parts = p.split()
            # Sub-comando: 'done <numero>' marca tarea N como completada.
            # Strict: exactamente 2 tokens, segundo numérico. Cualquier
            # otra cosa ("done foo bar") se trata como texto libre y
            # cae al add.
            if len(parts) == 2 and parts[0].lower() == "done" and parts[1].isdigit():
                ejecutar_seguro(
                    [str(SCRIPTS_DIR / "todos.sh"), "done", parts[1]],
                    "todos.sh done",
                )
            else:
                ejecutar_seguro(
                    [str(SCRIPTS_DIR / "todos.sh"), "add", p],
                    "todos.sh add",
                )

    elif comando == "tareas":
        ejecutar_seguro([str(SCRIPTS_DIR / "todos.sh"), "list"], "todos.sh list")

    elif comando == "diario":
        ejecutar_seguro([str(SCRIPTS_DIR / "daily.sh")], "daily.sh")

    elif comando == "inicio":
        ejecutar_seguro([str(SCRIPTS_DIR / "home.sh")], "home.sh")

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
    #   watson preguntar ia "resume PatrickOS"
    if len(sys.argv) > 1:
        raw = " ".join(sys.argv[1:])
        # Prefijos con payload ("preguntar ia <texto>", "nota <texto>" y
        # sus aliases) se rutean aparte para preservar el texto sin
        # lowercasing y sin abrir prompt interactivo. Exigimos exact
        # match o un espacio después del prefijo, así "preguntarx" o
        # "notar" no se confunden con un prefijo válido. Pasamos el
        # prefijo tal cual a ejecutar_comando — el alias map lo
        # normaliza a la forma canónica.
        lowered = raw.lower()
        for prefijo in _PAYLOAD_PREFIXES:
            if lowered == prefijo or lowered.startswith(prefijo + " "):
                resto = raw[len(prefijo):].lstrip()
                ejecutar_comando(prefijo, resto or None)
                return
        ejecutar_comando(raw)
        return

    # Modo interactivo: menú con prompt.
    mostrar_ayuda()
    activo = True
    while activo:
        comando = input("\nwatson> ")
        activo = ejecutar_comando(comando)


if __name__ == "__main__":
    main()
