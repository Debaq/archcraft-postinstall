# LabSim: simulador de laboratorio de audiología (PyInstaller + Qt).
# Se actualiza sola (apply_update.sh): una vez instalada, el postinstall no la toca.

APP_NAME=LabSim
APP_DESC="Simulador de laboratorio de audiología"
APP_PROC=LabSim # nombre del proceso (pgrep -x)
# Librerías que Qt (bundleado por PyInstaller) toma del sistema
APP_PKGS=(xcb-util-cursor xcb-util-wm xcb-util-keysyms xcb-util-image xcb-util-renderutil libxkbcommon-x11 pipewire-pulse)
APP_ENV=(
	LABSIM_AUTO_UPDATE=1 # actualiza sin preguntar
	LABSIM_KIOSKO=1      # sabe que corre en el kiosko
)

# Instala en $1 (debe quedar $1/run.sh). El tar trae la carpeta LabSim/ con el ejecutable y run.sh.
app_install() {
	local dest="$1" url tmp
	if [[ -x "$dest/LabSim" ]]; then
		ok "LabSim ya instalado en $dest (se actualiza solo)"
		return 0
	fi
	url="$(gh_asset_url Debaq/LabSim pyinstaller-v LabSim-linux-x86_64.tar.gz)"
	[[ -n "$url" ]] || { warn "No se encontró el release de LabSim"; return 1; }
	tmp="$(mktemp -d)"
	echo "  Descargando $url"
	curl -fL --progress-bar -o "$tmp/app.tar.gz" "$url"
	tar -xzf "$tmp/app.tar.gz" -C "$tmp"
	[[ -x "$tmp/LabSim/LabSim" ]] || { warn "El tar no trae LabSim/LabSim"; rm -rf "$tmp"; return 1; }
	sudo mv "$tmp/LabSim" "$dest"
	rm -rf "$tmp"
	ok "LabSim instalado en $dest"
}

app_icon() { ls "$1"/resources/img/Logo*.png 2>/dev/null | head -1; }
