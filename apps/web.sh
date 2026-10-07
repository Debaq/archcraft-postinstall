# Web: una página en Chromium a pantalla completa (modo kiosko), p. ej. un punto de atención.
# La dirección se pregunta al elegir la app (o --url=…) y queda en $ESTADO/url; cada corrida
# del postinstall la vuelve a escribir en $APP_DIR/url. Chromium se actualiza con pacman.

APP_NAME=Web
APP_DESC="Página web en Chromium a pantalla completa (punto de atención)"
APP_PROC=chromium # nombre del proceso (pgrep -x)
APP_DIR=/opt/web
# yad: diálogo para elegir la red Wi-Fi con el mouse (wifi.sh), al abrir sin red y desde el menú
APP_PKGS=(chromium yad)
APP_ENV=()

WEB_URL_FILE="$ESTADO/url"

# Pregunta la dirección si falta o si $1 es 1 (app recién elegida o --elegir)
app_setup() {
	local preguntar="$1" url r
	url="$(cat "$WEB_URL_FILE" 2>/dev/null || true)"
	if [[ -n "$url" && "$preguntar" != 1 ]]; then
		ok "Página: $url"
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
	ok "Página: $r"
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
wifi="$HOME/.config/kiosko/wifi.sh"

# Sin red: espera a que se asocie (al arrancar tarda) y si no, ofrece elegir una Wi-Fi.
# Vale cualquier red (también solo local: la página puede estar en un servidor del lugar).
conectado() { case "$(nmcli -t -f STATE general 2>/dev/null)" in connected*) return 0 ;; esac; return 1; }
i=0
while ! conectado && [ $i -lt 20 ]; do sleep 1; i=$((i + 1)); done
conectado || { [ -x "$wifi" ] && "$wifi"; }

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
}

app_icon() { echo chromium; }
