# Web: una página en Chromium a pantalla completa (modo kiosko), p. ej. un punto de atención.
# La dirección y el nombre (menú y acceso directo) se preguntan al elegir la app (o --url=… y
# --nombre=…) y quedan en $ESTADO/url y $ESTADO/nombre; cada corrida del postinstall vuelve a
# escribir la dirección en $APP_DIR/url. Chromium se actualiza con pacman.

WEB_URL_FILE="$ESTADO/url"
WEB_NAME_FILE="$ESTADO/nombre"
WEB_NAME_DEFAULT=Web

APP_NAME="$(cat "$WEB_NAME_FILE" 2>/dev/null || true)"
APP_NAME="${APP_NAME:-$WEB_NAME_DEFAULT}"
APP_DESC="Página web en Chromium a pantalla completa (punto de atención)"
APP_PROC=chromium # nombre del proceso (pgrep -x)
APP_DIR=/opt/web  # fija: no cambia con el nombre
APP_PKGS=(chromium)
APP_ENV=()

# Pregunta la dirección si falta, y la dirección y el nombre si $1 es 1 (app recién elegida o --elegir)
app_setup() {
	local preguntar="$1" url r
	# Sin caracteres que rompan el menú de Openbox (XML) ni el sed que lo arma
	local nombre_ok='^[[:alnum:] ._()-]+$'
	url="$(cat "$WEB_URL_FILE" 2>/dev/null || true)"
	if [[ -n "$url" && "$preguntar" != 1 ]]; then
		ok "Página: $url ($APP_NAME)"
		return 0
	fi
	if [[ ! -t 0 ]]; then
		[[ -n "$url" ]] && return 0
		warn "Falta la dirección de la página: ./postinstall.sh --url=https://…"
		return 1
	fi
	step "¿Qué página abre el kiosko?"
	r=""
	until [[ "$r" =~ ^https?://[^[:space:]]+$ ]]; do
		read -rp "  Dirección${url:+ [$url]}: " r || return 1
		r="${r:-$url}"
		# Sin esquema se asume https
		[[ -n "$r" && "$r" != *://* ]] && r="https://$r"
	done
	echo "$r" >"$WEB_URL_FILE"
	r=""
	until [[ "$r" =~ $nombre_ok ]]; do
		[[ -n "$r" ]] && warn "Solo letras, números, espacios y . _ ( ) -"
		read -rp "  Nombre en el menú [$APP_NAME]: " r || return 1
		r="${r:-$APP_NAME}"
	done
	echo "$r" >"$WEB_NAME_FILE"
	APP_NAME="$r"
	ok "Página: $(cat "$WEB_URL_FILE") ($APP_NAME)"
}

# Deja en $1 run.sh (abre Chromium) y url
app_install() {
	local dest="$1" url tmp
	url="$(cat "$WEB_URL_FILE" 2>/dev/null || true)"
	[[ -n "$url" ]] || { warn "Falta la dirección de la página: ./postinstall.sh --url=https://…"; return 1; }
	tmp="$(mktemp -d)"
	echo "$url" >"$tmp/url"
	cat >"$tmp/run.sh" <<'SH'
#!/bin/sh
# Abre la página de ./url en Chromium a pantalla completa, con un perfil propio del kiosko.
cd "$(dirname "$0")"
url="$(cat url)"
perfil="$HOME/.config/kiosko-web"

# Tras un apagado brusco Chromium ofrece "restaurar páginas": se marca la salida como normal
prefs="$perfil/Default/Preferences"
[ -f "$prefs" ] && sed -i -e 's/"exited_cleanly":false/"exited_cleanly":true/' \
	-e 's/"exit_type":"[^"]*"/"exit_type":"Normal"/' "$prefs"

# --autoplay-policy: la página puede sonar (avisos, llamados de turno) sin que nadie la toque.
# Sin red, la página de error de Chromium recarga sola cuando vuelve la conexión.
exec chromium --user-data-dir="$perfil" --kiosk --app="$url" \
	--no-first-run --noerrdialogs --disable-infobars --disable-session-crashed-bubble \
	--disable-features=Translate --password-store=basic --check-for-update-interval=31536000 \
	--overscroll-history-navigation=0 --disable-pinch --autoplay-policy=no-user-gesture-required
SH
	chmod +x "$tmp/run.sh"
	sudo rm -rf "$dest"
	sudo mv "$tmp" "$dest"
	ok "Web abre $url"

	# Políticas de Chromium, solo para el sitio de la página: cámara y micrófono sin preguntar.
	# Chromium solo los da en sitios seguros (https o localhost): uno http (p. ej. un servidor del
	# lugar por IP) se trata como seguro, o la cámara no funcionaría aunque esté permitida.
	local origen="${url%%\?*}"
	origen="$(sed -E 's|^([a-z]+://[^/]+).*|\1|' <<<"$origen")"
	jq -n --arg o "$origen" '{
		AudioCaptureAllowed: true, VideoCaptureAllowed: true,
		AudioCaptureAllowedUrls: [$o], VideoCaptureAllowedUrls: [$o]
	} + (if ($o | startswith("http://")) then {OverrideSecurityRestrictionsOnInsecureOrigin: [$o]} else {} end)' |
		sys_write /etc/chromium/policies/managed/kiosko.json && ok "Chromium: cámara y micrófono permitidos en $origen"
	return 0
}

app_icon() { echo chromium; }
