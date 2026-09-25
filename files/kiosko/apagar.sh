#!/bin/sh
# Apagado ordenado: frena el relanzador, manda SIGTERM a @APPNAME@ (la señal con la
# que systemd pide cerrar al apagar; la app guarda informes y logs y sale) y recién
# entonces apaga o reinicia. Si no cierra en 15 s, se apaga igual.
# Uso: apagar.sh poweroff|reboot
accion="${1:-poweroff}"
touch "@KDIR@/.saliendo"
if pkill -TERM -x "@APPNAME@"; then
	i=0
	while pgrep -x "@APPNAME@" >/dev/null && [ $i -lt 15 ]; do sleep 1; i=$((i + 1)); done
fi
systemctl "$accion"
