# postinstall: siempre (revisa si la app tiene versión nueva)
# Instala la app del kiosko (apps/<nombre>.sh) en $APP_DIR (por defecto $APPS_DIR/<nombre>), con acceso directo.
# La carpeta queda a nombre del usuario para que el auto-update de la app pueda escribir.

pkg_install jq "${APP_PKGS[@]}"

dest="$APP_DIR"
app_install "$dest"
sudo chown -R "$USER:" "$dest"

icon="$(app_icon "$dest" || true)"
sys_write "/usr/share/applications/$APP_NAME.desktop" <<DESKTOP && ok "Acceso directo $APP_NAME.desktop"
[Desktop Entry]
Type=Application
Name=$APP_NAME
Exec=$dest/run.sh
Path=$dest
Icon=${icon:-application-x-executable}
Categories=Education;
Terminal=false
DESKTOP
ok "$APP_NAME lista"
