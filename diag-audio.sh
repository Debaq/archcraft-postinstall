#!/usr/bin/env bash
# Diagnostica y repara el audio de un equipo.
# Correr con el usuario del kiosko (sin sudo), desde la terminal del menú o por SSH.
# Uso: ./diag-audio.sh              diagnostica, repara, vuelve a diagnosticar y prueba un tono
#      ./diag-audio.sh --solo-diag  solo diagnostica
# Todo queda en ~/audio-<hostname>.txt
set -uo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
source "$ROOT/lib.sh"
source "$ROOT/config.sh"

[[ $EUID -ne 0 ]] || { echo "Ejecutar con el usuario del kiosko, sin sudo" >&2; exit 1; }

# Por SSH no vienen: sin ellas no se llega a PipeWire ni a systemctl --user
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
export DBUS_SESSION_BUS_ADDRESS="${DBUS_SESSION_BUS_ADDRESS:-unix:path=$XDG_RUNTIME_DIR/bus}"
OUT="$HOME/audio-$(hostnamectl hostname 2>/dev/null || cat /etc/hostname).txt"
SESSION="$(loginctl list-sessions --no-legend 2>/dev/null | awk -v u="$USER" '$3 == u {print $1; exit}')"
UNITS=(pipewire.socket pipewire.service pipewire-pulse.socket pipewire-pulse.service wireplumber.service)

CMDS=(
	"hostnamectl"
	"uname -r"
	"lspci -nnk | grep -iA3 audio"
	"cat /proc/asound/cards"
	"aplay -l"
	"pacman -Q ${AUDIO_PKGS[*]} linux-firmware pulseaudio"
	"systemctl --user --no-pager status pipewire pipewire-pulse wireplumber"
	"wpctl status"
	"wpctl inspect @DEFAULT_AUDIO_SINK@"
	"pactl info"
	"journalctl -b -k --no-pager | grep -iE 'snd|sof|hda|audio|firmware'"
	"journalctl -b --user --no-pager -u pipewire -u wireplumber | tail -40"
	"loginctl show-session $SESSION"
	"groups"
)

diag() {
	local c
	for c in "${CMDS[@]}"; do
		echo "===== $c"
		eval "$c" 2>&1
		echo
	done
}

reparar() {
	local pa p i sinks out def n ctl

	step "Paquetes"
	sudo -v || return 1
	# PulseAudio choca con pipewire-pulse: si quedó instalado, ninguno de los dos anda bien
	mapfile -t pa < <(pacman -Qq | grep -E '^pulseaudio')
	if ((${#pa[@]})); then
		sudo pacman -Rdd --noconfirm "${pa[@]}" >/dev/null && ok "Quitado ${pa[*]} (choca con PipeWire)"
	fi
	if [[ -z "$(pacman -T "${AUDIO_PKGS[@]}")" ]]; then
		ok "Paquetes de audio completos"
	else
		pkg_install "${AUDIO_PKGS[@]}" || warn "No se pudo instalar: prueba con sudo pacman -Syu y repite"
	fi
	sudo pacman -D --asexplicit "${AUDIO_PKGS[@]}" &>/dev/null

	step "Mezclador ALSA"
	for n in /proc/asound/card[0-9]*; do
		n="${n##*card}"
		for ctl in Master Speaker Headphone PCM Front; do amixer -q -c "$n" sset "$ctl" unmute 2>/dev/null; done
	done
	ok "Canales de las tarjetas sin silencio"

	step "PipeWire"
	systemctl --user unmask "${UNITS[@]}" &>/dev/null
	systemctl --user enable pipewire.socket pipewire-pulse.socket wireplumber.service &>/dev/null
	# WirePlumber recuerda la salida y el perfil elegidos: si quedó en un HDMI sin parlantes o
	# en un perfil apagado, se queda ahí. Se borra para que vuelva a elegir.
	if [[ -d "$HOME/.local/state/wireplumber" ]]; then
		rm -rf "$HOME/.local/state/wireplumber.bak"
		mv "$HOME/.local/state/wireplumber" "$HOME/.local/state/wireplumber.bak"
		ok "Estado de WirePlumber reiniciado (respaldo en ~/.local/state/wireplumber.bak)"
	fi
	systemctl --user restart pipewire pipewire-pulse wireplumber && ok "Servicios reiniciados"

	step "Salida de audio"
	for i in $(seq 15); do
		pactl list short sinks 2>/dev/null | grep -q alsa_output && break
		sleep 1
	done
	sinks="$(pactl list short sinks 2>/dev/null | awk '{print $2}' | grep alsa_output)"
	out='analog|Speaker|Headphone'
	# Sin salida analógica: la tarjeta puede estar en un perfil solo HDMI o apagado
	if ! grep -qE "$out" <<<"$sinks"; then
		for n in $(pactl list short cards 2>/dev/null | awk '{print $2}'); do
			for p in output:analog-stereo+input:analog-stereo output:analog-stereo; do
				pactl set-card-profile "$n" "$p" 2>/dev/null && { ok "Perfil $p en $n"; break; }
			done
		done
		sleep 2
		sinks="$(pactl list short sinks 2>/dev/null | awk '{print $2}' | grep alsa_output)"
	fi
	if [[ -z "$sinks" ]]; then
		warn "PipeWire no ve ninguna salida de audio"
	else
		# Parlantes/audífonos antes que HDMI (los monitores del laboratorio suelen no tener)
		out="$(grep -m1 -E "$out" <<<"$sinks")"
		def="$(pactl get-default-sink 2>/dev/null)"
		if [[ -n "$out" && ! "$def" =~ analog|Speaker|Headphone ]]; then
			pactl set-default-sink "$out" && ok "Salida por defecto: $out"
		else
			ok "Salida por defecto: $def"
		fi
		wpctl set-volume @DEFAULT_AUDIO_SINK@ "$KIOSK_VOLUME%" && wpctl set-mute @DEFAULT_AUDIO_SINK@ 0 &&
			ok "Volumen $KIOSK_VOLUME%, sin silencio"
	fi
}

diag >"$OUT"
echo "Diagnóstico guardado en $OUT"
[[ "${1:-}" == --solo-diag ]] && exit 0

echo "################ REPARACIÓN" >>"$OUT"
reparar 2>&1 | tee -a "$OUT"
echo -e "\n################ DESPUÉS DE REPARAR" >>"$OUT"
diag >>"$OUT"

# Tono de prueba: la respuesta queda en el archivo
if [[ -t 0 ]] && command -v speaker-test &>/dev/null; then
	step "Prueba"
	echo "Suena un tono por el parlante izquierdo y luego por el derecho..."
	timeout 6 speaker-test -c 2 -t sine -f 440 &>/dev/null
	read -rp "¿Se escuchó el tono? [s/n] " r
	echo "===== Tono de prueba: ${r:-sin respuesta}" >>"$OUT"
fi

sed -i 's/\x1b\[[0-9;]*m//g' "$OUT"
# El firmware y los perfiles de tarjeta solo se cargan al arrancar
grep -qE 'Instalados:.*(firmware|alsa-ucm-conf)' "$OUT" && warn "Se instaló firmware de audio: reinicia el equipo para que se cargue"
ok "Listo. Si sigue sin audio, envía $OUT"
