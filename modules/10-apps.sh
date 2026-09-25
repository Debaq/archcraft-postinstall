# Instala las apps de APPS desde GitHub Releases en $APPS_DIR/<nombre>.
# La carpeta queda a nombre del usuario para que el auto-update de la app pueda escribir.

# Librerías que Qt (bundleado por PyInstaller) toma del sistema
pkg_install jq xcb-util-cursor xcb-util-wm xcb-util-keysyms xcb-util-image \
	xcb-util-renderutil libxkbcommon-x11 pipewire-pulse

for entry in "${APPS[@]}"; do
	IFS='|' read -r name repo prefix asset <<<"$entry"
	dest="$APPS_DIR/$name"

	if [[ -x "$dest/$name" ]]; then
		ok "$name ya instalado en $dest (se actualiza solo)"
	else
		url="$(gh_asset_url "$repo" "$prefix" "$asset")"
		[[ -n "$url" ]] || { warn "No se encontró $asset en $repo"; continue; }
		tmp="$(mktemp -d)"
		echo "  Descargando $url"
		curl -fL --progress-bar -o "$tmp/app.tar.gz" "$url"
		tar -xzf "$tmp/app.tar.gz" -C "$tmp"
		[[ -x "$tmp/$name/$name" ]] || { warn "$asset no trae $name/$name"; rm -rf "$tmp"; continue; }
		sudo mv "$tmp/$name" "$dest"
		rm -rf "$tmp"
		ok "$name instalado en $dest"
	fi
	sudo chown -R "$USER:" "$dest"

	icon="$(ls "$dest"/resources/img/Logo*.png 2>/dev/null | head -1)"
	sys_write "/usr/share/applications/$name.desktop" <<-DESKTOP && ok "Acceso directo $name.desktop"
		[Desktop Entry]
		Type=Application
		Name=$name
		Exec=$dest/run.sh
		Path=$dest
		Icon=${icon:-application-x-executable}
		Categories=Education;
		Terminal=false
	DESKTOP
done
ok "Apps listas"
