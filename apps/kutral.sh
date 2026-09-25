# Kütral: catálogo de películas, series, IPTV y juegos (Tauri + mpv).
# En Linux no se actualiza sola: cada corrida del postinstall baja el release nuevo si hay.

APP_NAME=Kutral
APP_DESC="Catálogo de películas, series, IPTV y juegos"
APP_PROC=kutral # nombre del proceso (pgrep -x)
# El binario suelto enlaza webkit2gtk, gtk3 y libmpv del sistema. mpv trae ffprobe (ffmpeg);
# brightnessctl: brillo desde la app en modo Kütral OS.
APP_PKGS=(webkit2gtk-4.1 gtk3 mpv brightnessctl)
APP_ENV=(
	KUTRAL_OS=1                      # modo equipo dedicado: wifi, brillo, volumen y apagado desde la app
	WEBKIT_DISABLE_DMABUF_RENDERER=1 # sin esto WebKitGTK queda en blanco en varias GPU viejas
)

KUTRAL_REPO=Debaq/kutral

# Instala o actualiza en $1 (debe quedar $1/run.sh). Arma vendor/ como src-tauri/vendor/fetch.sh
# (el binario lo busca junto a sí): yt-dlp, uosc y los .conf de mpv del mismo tag. mpv es el del sistema.
app_install() {
	local dest="$1" rel tag url tmp f raw
	if ! rel="$(curl -fsSL "https://api.github.com/repos/$KUTRAL_REPO/releases/latest")"; then
		[[ -x "$dest/kutral" ]] && { warn "Sin red: Kutral queda en $(cat "$dest/VERSION" 2>/dev/null)"; return 0; }
		warn "No se pudo consultar el release de Kutral"
		return 1
	fi
	tag="$(jq -r .tag_name <<<"$rel")"
	if [[ -x "$dest/kutral" && "$(cat "$dest/VERSION" 2>/dev/null)" == "$tag" ]]; then
		ok "Kutral $tag al día"
		return 0
	fi
	url="$(jq -r --arg a "kutral-$tag-linux-x86_64.bin" '.assets[] | select(.name == $a) | .browser_download_url' <<<"$rel")"
	[[ -n "$url" ]] || { warn "El release $tag de Kutral no trae el binario de Linux"; return 1; }

	tmp="$(mktemp -d)"
	echo "  Descargando $url"
	curl -fL --progress-bar -o "$tmp/kutral" "$url"
	chmod +x "$tmp/kutral"

	mkdir -p "$tmp/vendor/mpv-config/script-opts"
	curl -fsSL -o "$tmp/vendor/yt-dlp" https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp_linux
	chmod +x "$tmp/vendor/yt-dlp"
	url="$(curl -fsSL https://api.github.com/repos/tomasklaen/uosc/releases/latest |
		jq -r '.assets[] | select(.name == "uosc.zip") | .browser_download_url')"
	curl -fsSL -o "$tmp/uosc.zip" "$url"
	bsdtar -xf "$tmp/uosc.zip" -C "$tmp/vendor/mpv-config"
	rm "$tmp/uosc.zip"
	raw="https://raw.githubusercontent.com/$KUTRAL_REPO/$tag/src-tauri"
	for f in mpv.conf input.conf iptv-input.conf script-opts/uosc.conf; do
		curl -fsSL -o "$tmp/vendor/mpv-config/$f" "$raw/vendor/mpv-config/$f"
	done
	curl -fsSL -o "$tmp/icon.png" "$raw/icons/128x128.png" || true

	printf '#!/bin/sh\ncd "$(dirname "$0")"\nexec ./kutral "$@"\n' >"$tmp/run.sh"
	chmod +x "$tmp/run.sh"
	echo "$tag" >"$tmp/VERSION"
	# Si está abierta sigue con la versión vieja hasta que se reabra
	sudo rm -rf "$dest"
	sudo mv "$tmp" "$dest"
	ok "Kutral $tag instalado en $dest"
}

app_icon() { [[ -f "$1/icon.png" ]] && echo "$1/icon.png"; }
