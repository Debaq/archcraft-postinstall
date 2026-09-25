#!/bin/sh
# Mantiene @APPNAME@ abierto.
# - Si se cae (código de salida distinto de 0), la vuelve a abrir.
# - Si sale normal (código 0: el docente la cerró), no la reabre: queda el menú
#   de mantenimiento (clic derecho en el fondo), que tiene "@APPNAME@" para volver.
# - Durante su auto-update (apply_update.sh) no hace nada: el updater la reabre.
# - Con apagar.sh en curso (.saliendo) termina.
# Una sola instancia (el menú también la lanza).
exec 9>"@KDIR@/.relanzar.lock"
flock -n 9 || exit 0
rm -f "@KDIR@/.saliendo"

corriendo() { pgrep -x "@APPNAME@" >/dev/null || pgrep -f apply_update.sh >/dev/null; }

while :; do
	if ! corriendo; then
		"@APP@" >/dev/null 2>&1
		rc=$?
		[ -e "@KDIR@/.saliendo" ] && exit 0
		sleep 2
		# Salida normal sin update en curso: la cerró el docente
		[ $rc -eq 0 ] && ! corriendo && exit 0
	fi
	# Abierta por el updater (no es hija nuestra): se vigila por pgrep
	sleep 3
	[ -e "@KDIR@/.saliendo" ] && exit 0
done
