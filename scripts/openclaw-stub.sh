#!/usr/bin/env bash
# openclaw-stub.sh — stub no-op de OpenClaw para preparar integración
# agéntica futura. NO ejecuta herramientas, NO toca red, NO carga runtime.
# Su única función hoy es responder consistentemente y servir de hook para
# que Watson tenga el comando 'openclaw'/'claw' cableado antes de que el
# runtime real exista.

echo "OpenClaw Runtime: stub"
echo "Estado: no instalado / no activo"
echo "Modo seguro: sin ejecución de herramientas"
echo "Próximo paso: integrar runtime aislado con whitelist"
exit 0
