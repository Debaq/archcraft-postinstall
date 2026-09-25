# LabNAS: servidor de laboratorio (archivos, impresoras 3D, streaming, tareas…) con web UI en :3001.
# El equipo corre el servidor como servicio con el usuario del kiosko (no root: así mpv suena en su
# sesión, la terminal web abre su shell y ve su home; se actualiza solo desde su web) y el kiosko
# muestra la UI con labnas-viewer (WebKitGTK), que espera a que el servidor responda.

APP_NAME=LabNAS
APP_DESC="Servidor de laboratorio con su interfaz web"
APP_PROC=labnas-viewer # nombre del proceso (pgrep -x)
APP_DIR=/opt/labnas-viewer
# webkit2gtk y gtk3: el visor. Opcionales del servidor (como su install.sh --deps, sin cups, que el
# kiosko apaga): mpv y yt-dlp música y video, ffmpeg timelapse, rsync respaldos, smartmontools SMART.
# dunst y libnotify: el visor avisa con notify-send (impresión terminada, respaldo fallido, descargas);
# sin un daemon de notificaciones (el kiosko quita dunst) esos avisos se pierden.
# libayatana-appindicator: el visor crea un ícono de bandeja y sin la librería se cae al abrir
# (la carga con dlopen: ldd no la muestra).
APP_PKGS=(webkit2gtk-4.1 gtk3 libayatana-appindicator mpv yt-dlp ffmpeg rsync smartmontools dunst libnotify)
APP_ENV=(
	WEBKIT_DISABLE_DMABUF_RENDERER=1 # sin esto WebKitGTK queda en blanco en varias GPU viejas
)
APP_WINDOW='title="LabNAS"' # el visor abre en 1280x800: Openbox lo pone a pantalla completa

LABNAS_REPO=Debaq/labnas
LABNAS_SERVER=/opt/labnas

# Instala o actualiza el visor en $1 (debe quedar $1/run.sh); el servidor, solo si falta.
app_install() {
	local dest="$1" rels tag="" url="" tmp srv_ok=1
	rels="$(curl -fsSL "https://api.github.com/repos/$LABNAS_REPO/releases?per_page=30")" || {
		[[ -x "$dest/labnas-viewer" && -x "$LABNAS_SERVER/labnas-backend" ]] && { warn "Sin red: LabNAS queda como está"; return 0; }
		warn "No se pudo consultar los releases de LabNAS"
		return 1
	}

	# Servidor: con el install.sh oficial (checksum, unidad sin root con CAP_NET_RAW y
	# CAP_NET_BIND_SERVICE, ufw, espera a /api/health). Una vez instalado se actualiza desde su
	# web; se reinstala solo si falta o si la unidad es la vieja que corría como root.
	# Si el servidor falla, el visor igual se instala (el kiosko tiene qué abrir) y el módulo
	# se marca fallido al final para reintentarlo en la próxima corrida.
	if [[ -x "$LABNAS_SERVER/labnas-backend" ]] && grep -q "^User=$USER$" /etc/systemd/system/labnas.service 2>/dev/null; then
		ok "Servidor LabNAS ya instalado en $LABNAS_SERVER (se actualiza solo)"
	else
		# La versión va explícita: sin --version, install.sh la busca con curl | grep -m1, que en
		# Arch corta el pipe y sale con curl (23) antes de instalar nada.
		read -r tag url < <(jq -r '[.[] | select(.draft | not) | .tag_name as $t | .assets[] | select(.name == "install.sh")
			| "\($t) \(.browser_download_url)"][0] // empty' <<<"$rels") || true
		tmp="$(mktemp -d)"
		if [[ -z "${url:-}" ]] || ! curl -fsSL -o "$tmp/install.sh" "$url"; then
			warn "No se pudo bajar el install.sh de LabNAS"
			srv_ok=0
		# install.sh termina con error al mostrar la IP (usa hostname -I, que el de Arch no tiene)
		# aunque ya dejó todo instalado: vale lo que quedó, no su código de salida.
		elif ! sudo bash "$tmp/install.sh" --user "$USER" --dir "$LABNAS_SERVER" --version "$tag" | sed 's/^/  /'; then
			if [[ -x "$LABNAS_SERVER/labnas-backend" ]] && systemctl is-active -q labnas.service; then
				ok "Servidor LabNAS activo (install.sh terminó con error después de instalarlo)"
			else
				warn "No se pudo instalar el servidor LabNAS (journalctl -u labnas -n 50)"
				srv_ok=0
			fi
		fi
		rm -rf "$tmp"
	fi

	# Visor: del release más nuevo que lo traiga
	url=""
	read -r tag url < <(jq -r '[.[] | .tag_name as $t | .assets[] | select(.name == "labnas-viewer-\($t)-linux-x86_64.tar.gz")
		| "\($t) \(.browser_download_url)"][0] // empty' <<<"$rels") || true
	[[ -n "${url:-}" ]] || { warn "Ningún release de LabNAS trae el visor (labnas-viewer-<tag>-linux-x86_64.tar.gz)"; return 1; }
	if [[ -x "$dest/labnas-viewer" && "$(cat "$dest/VERSION" 2>/dev/null)" == "$tag" ]]; then
		ok "Visor LabNAS $tag al día"
		((srv_ok))
		return
	fi
	tmp="$(mktemp -d)"
	echo "  Descargando $url"
	curl -fL --progress-bar -o "$tmp/viewer.tar.gz" "$url"
	if [[ "$(curl -fsSL "$url.sha256" | cut -d' ' -f1)" != "$(sha256sum "$tmp/viewer.tar.gz" | cut -d' ' -f1)" ]]; then
		warn "Checksum del visor no coincide: descarga corrupta o alterada"
		rm -rf "$tmp"
		return 1
	fi
	tar -xzf "$tmp/viewer.tar.gz" -C "$tmp"
	[[ -x "$tmp/labnas-viewer/labnas-viewer" ]] || { warn "El tar no trae labnas-viewer/labnas-viewer"; rm -rf "$tmp"; return 1; }
	printf '#!/bin/sh\ncd "$(dirname "$0")"\nexec ./labnas-viewer "$@"\n' >"$tmp/labnas-viewer/run.sh"
	chmod +x "$tmp/labnas-viewer/run.sh"
	echo "$tag" >"$tmp/labnas-viewer/VERSION"
	sudo rm -rf "$dest"
	sudo mv "$tmp/labnas-viewer" "$dest"
	rm -rf "$tmp"
	ok "Visor LabNAS $tag instalado en $dest"
	((srv_ok))
}

app_icon() { ls "$1"/assets/*.svg 2>/dev/null | head -1; }
