#!/bin/sh
# Elegir y conectar una red Wi-Fi con el mouse (yad + nmcli). Lo abren el menú, Ctrl+Alt+W
# (encima de la app) y la app web cuando arranca sin red. Las redes quedan guardadas y se
# reconectan solas al prender. Sin yad (no se corrió 60-paquetes), abre nmtui en la terminal.
command -v yad >/dev/null || exec @TERM@ -e nmtui

# Una sola ventana: si ya está abierta, no abre otra
exec 8>"@KDIR@/.wifi.lock"
flock -n 8 || exit 0

titulo="Wi-Fi"
error() { yad --title="$titulo" --center --no-markup --width=360 --image=dialog-error --text="$1" --button="Aceptar:0"; }

# Conecta mostrando un aviso mientras tanto; deja la salida de nmcli en $salida
con_aviso() {
	yad --title="$titulo" --center --no-markup --width=320 --no-buttons --text="Conectando a «$ssid»…" &
	aviso=$!
	salida="$(nmcli --wait 30 "$@" 2>&1)"
	rc=$?
	kill $aviso 2>/dev/null
	return $rc
}

while :; do
	# Una fila por red (la de mejor señal si se repite), ordenadas por señal. Campos de -t: IN-USE,
	# SIGNAL, SECURITY y SSID (en el SSID los ":" vienen como "\:"). Sin nombre (ocultas) no se listan.
	redes="$(nmcli -t -f IN-USE,SIGNAL,SECURITY,SSID device wifi list --rescan yes 2>/dev/null |
		sort -t: -k2,2nr | awk -F: '{ s = $0; sub(/^([^:]*:){3}/, "", s); if (s != "" && !v[s]++) print }')"
	elegida="$(printf '%s\n' "$redes" | while IFS=: read -r uso senal seg ssid; do
		[ -n "$ssid" ] || continue
		[ "$uso" = "*" ] && uso="Conectada" || uso=""
		[ -n "$seg" ] && seg="Con clave" || seg="Abierta"
		printf '%s\n%s\n%s\n%s\n' "$ssid" "$senal" "$seg" "$uso"
	done | yad --list --title="$titulo" --center --no-markup --width=520 --height=420 \
		--text="Elegir la red (doble clic o Conectar):" \
		--column="Red" --column="Señal:BAR" --column="Seguridad" --column="Estado" \
		--print-column=1 --separator="" \
		--button="Actualizar:2" --button="Cerrar:1" --button="Conectar:0")"
	case $? in
	0) ;;
	2) continue ;;
	*) exit 0 ;;
	esac
	[ -n "$elegida" ] || continue
	ssid="$elegida"
	# La de la lista viene escapada: "\:" es ":" y "\\" es "\"
	ssid="$(printf '%s' "$ssid" | sed -e 's/\\:/:/g' -e 's/\\\\/\\/g')"
	seg="$(printf '%s\n' "$redes" | n="$elegida" awk -F: '{ s = $0; sub(/^([^:]*:){3}/, "", s); if (s == ENVIRON["n"]) { print $3; exit } }')"

	# Guardada: se usa. Si falla (clave cambiada), se borra y se pide la clave de nuevo
	if nmcli -t -f NAME connection show | grep -qxF "$ssid"; then
		con_aviso connection up id "$ssid" && exit 0
		nmcli connection delete id "$ssid" >/dev/null 2>&1
	fi
	if [ -n "$seg" ]; then
		clave="$(yad --entry --title="$titulo" --center --no-markup --width=360 --hide-text \
			--text="Clave de «$ssid»:" --button="Cancelar:1" --button="Conectar:0")" || continue
		con_aviso device wifi connect "$ssid" password "$clave" && exit 0
	else
		con_aviso device wifi connect "$ssid" && exit 0
	fi
	# El intento fallido deja una conexión guardada con la clave mala: fuera
	nmcli connection delete id "$ssid" >/dev/null 2>&1
	error "No se pudo conectar a «$ssid».\n\n$salida"
done
