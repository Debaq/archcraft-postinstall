#!/usr/bin/env bash
# Junta en un archivo todo lo necesario para diagnosticar el audio de un equipo.
# Correr con el usuario del kiosko (sin sudo), desde la terminal del menú o por SSH.
# Uso: ./diag-audio.sh   → deja ~/audio-<hostname>.txt
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
OUT="$HOME/audio-$(hostnamectl hostname 2>/dev/null || cat /etc/hostname).txt"
SESSION="$(loginctl list-sessions --no-legend 2>/dev/null | awk -v u="$USER" '$3 == u {print $1; exit}')"

CMDS=(
	"hostnamectl"
	"uname -r"
	"lspci -nnk | grep -iA3 audio"
	"cat /proc/asound/cards"
	"aplay -l"
	"pacman -Q pipewire pipewire-pulse pipewire-alsa pipewire-jack wireplumber sof-firmware alsa-firmware alsa-ucm-conf alsa-utils linux-firmware pulseaudio"
	"systemctl --user --no-pager status pipewire pipewire-pulse wireplumber"
	"wpctl status"
	"wpctl inspect @DEFAULT_AUDIO_SINK@"
	"pactl info"
	"journalctl -b -k --no-pager | grep -iE 'snd|sof|hda|audio|firmware'"
	"journalctl -b --user --no-pager -u pipewire -u wireplumber | tail -40"
	"loginctl show-session $SESSION"
	"groups"
)

for c in "${CMDS[@]}"; do
	echo "===== $c"
	eval "$c" 2>&1
	echo
done >"$OUT"
echo "Listo: $OUT"
