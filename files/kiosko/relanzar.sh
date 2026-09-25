#!/bin/sh
# Mantiene @APPNAME@ abierto.
# - Si se cae (código de salida distinto de 0), la vuelve a abrir.
# - Si sale normal (código 0: el docente la cerró), queda el menú de mantenimiento
#   (clic derecho en el fondo) y la reabre tras @IDLE@ s sin uso de teclado ni mouse,
#   o antes si se elige "@APPNAME@" en el menú.
# - Durante su auto-update (apply_update.sh) no hace nada: el updater la reabre.
# - Con apagar.sh en curso (.saliendo) termina.
# Una sola instancia: si ya hay una (esperando), el menú le pide abrir ahora (.abrir).
exec 9>"@KDIR@/.relanzar.lock"
if ! flock -n 9; then
	touch "@KDIR@/.abrir"
	exit 0
fi
rm -f "@KDIR@/.saliendo" "@KDIR@/.abrir"

corriendo() { pgrep -x "@APPPROC@" >/dev/null || pgrep -f apply_update.sh >/dev/null; }

# Vuelve cuando toca reabrir: inactividad, pedido del menú o la abrió el updater
esperar() {
	while :; do
		[ -e "@KDIR@/.saliendo" ] && exit 0
		[ -e "@KDIR@/.abrir" ] && return
		corriendo && return
		[ "$(xprintidle 2>/dev/null || echo 0)" -ge $((@IDLE@ * 1000)) ] && return
		sleep 2
	done
}

while :; do
	if ! corriendo; then
		rm -f "@KDIR@/.abrir"
		"@APP@" >/dev/null 2>&1
		rc=$?
		rm -f "@KDIR@/.abrir"
		[ -e "@KDIR@/.saliendo" ] && exit 0
		sleep 2
		# Salida normal sin update en curso: la cerró el docente
		[ $rc -eq 0 ] && ! corriendo && { esperar; continue; }
	fi
	# Abierta por el updater (no es hija nuestra): se vigila por pgrep
	sleep 3
	[ -e "@KDIR@/.saliendo" ] && exit 0
done
