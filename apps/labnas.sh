# LabNAS: servidor de laboratorio (archivos, impresoras 3D, streaming, tareas…) con web UI en :3001.
# El equipo corre el servidor como servicio (root; se actualiza solo desde su web) y el kiosko
# muestra la UI con labnas-viewer (WebKitGTK), que espera a que el servidor responda.

APP_NAME=LabNAS
APP_DESC="Servidor de laboratorio con su interfaz web"
APP_PROC=labnas-viewer # nombre del proceso (pgrep -x)
APP_DIR=/opt/labnas-viewer
# webkit2gtk y gtk3: el visor. mpv y yt-dlp: música y video del servidor.
APP_PKGS=(webkit2gtk-4.1 gtk3 mpv yt-dlp)
APP_ENV=(
	WEBKIT_DISABLE_DMABUF_RENDERER=1 # sin esto WebKitGTK queda en blanco en varias GPU viejas
)
APP_WINDOW='title="LabNAS"' # el visor abre en 1280x800: Openbox lo pone a pantalla completa

LABNAS_REPO=Debaq/labnas
LABNAS_SERVER=/opt/labnas

# Instala o actualiza el visor en $1 (debe quedar $1/run.sh); el servidor, solo si falta.
app_install() {
	local dest="$1" rels tag="" url="" tmp
	rels="$(curl -fsSL "https://api.github.com/repos/$LABNAS_REPO/releases?per_page=30")" || {
		[[ -x "$dest/labnas-viewer" && -x "$LABNAS_SERVER/labnas-backend" ]] && { warn "Sin red: LabNAS queda como está"; return 0; }
		warn "No se pudo consultar los releases de LabNAS"
		return 1
	}

	# Servidor: después de instalado se actualiza desde su web (Sistema > Actualizar)
	if [[ -x "$LABNAS_SERVER/labnas-backend" ]]; then
		ok "Servidor LabNAS ya instalado en $LABNAS_SERVER (se actualiza solo)"
	else
		read -r tag url < <(jq -r '[.[] | .tag_name as $t | .assets[] | select(.name == "labnas-\($t)-linux-x86_64.tar.gz")
			| "\($t) \(.browser_download_url)"][0] // empty' <<<"$rels") || true
		[[ -n "${url:-}" ]] || { warn "No se encontró el servidor de LabNAS en los releases"; return 1; }
		tmp="$(mktemp -d)"
		echo "  Descargando $url"
		curl -fL --progress-bar -o "$tmp/labnas.tar.gz" "$url"
		tar -xzf "$tmp/labnas.tar.gz" -C "$tmp"
		[[ -x "$tmp/labnas/labnas-backend" ]] || { warn "El tar no trae labnas/labnas-backend"; rm -rf "$tmp"; return 1; }
		sudo mv "$tmp/labnas" "$LABNAS_SERVER"
		sudo chown -R root: "$LABNAS_SERVER"
		rm -rf "$tmp"
		ok "Servidor LabNAS $tag instalado en $LABNAS_SERVER"
	fi
	sys_write /etc/systemd/system/labnas.service <<-UNIT && sudo systemctl daemon-reload
		[Unit]
		Description=LabNAS Server
		After=network.target

		[Service]
		Type=simple
		ExecStart=$LABNAS_SERVER/labnas-backend
		WorkingDirectory=$LABNAS_SERVER
		Restart=always
		RestartSec=5

		[Install]
		WantedBy=multi-user.target
	UNIT
	sudo systemctl enable --now -q labnas.service && ok "Servicio labnas activo (http://localhost:3001)"

	# Visor: del release más nuevo que lo traiga
	url=""
	read -r tag url < <(jq -r '[.[] | .tag_name as $t | .assets[] | select(.name == "labnas-viewer-\($t)-linux-x86_64.tar.gz")
		| "\($t) \(.browser_download_url)"][0] // empty' <<<"$rels") || true
	[[ -n "${url:-}" ]] || { warn "Ningún release de LabNAS trae el visor (labnas-viewer-<tag>-linux-x86_64.tar.gz)"; return 1; }
	if [[ -x "$dest/labnas-viewer" && "$(cat "$dest/VERSION" 2>/dev/null)" == "$tag" ]]; then
		ok "Visor LabNAS $tag al día"
		return 0
	fi
	tmp="$(mktemp -d)"
	echo "  Descargando $url"
	curl -fL --progress-bar -o "$tmp/viewer.tar.gz" "$url"
	tar -xzf "$tmp/viewer.tar.gz" -C "$tmp"
	[[ -x "$tmp/labnas-viewer/labnas-viewer" ]] || { warn "El tar no trae labnas-viewer/labnas-viewer"; rm -rf "$tmp"; return 1; }
	printf '#!/bin/sh\ncd "$(dirname "$0")"\nexec ./labnas-viewer "$@"\n' >"$tmp/labnas-viewer/run.sh"
	chmod +x "$tmp/labnas-viewer/run.sh"
	echo "$tag" >"$tmp/labnas-viewer/VERSION"
	sudo rm -rf "$dest"
	sudo mv "$tmp/labnas-viewer" "$dest"
	rm -rf "$tmp"
	ok "Visor LabNAS $tag instalado en $dest"
}

app_icon() { ls "$1"/assets/*.svg 2>/dev/null | head -1; }
