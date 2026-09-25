# Kiosko: autologin en tty1 sin display manager, startx con Openbox mínimo
# (config propia en ~/.config/kiosko, no carga el autostart de Archcraft)
# y la app $KIOSK_APP abierta todo el tiempo.

pkg_install "${KEEP_PKGS[@]}"

# Terminal disponible para el menú
TERM_CMD=""
# (xfce4-terminal primero: alacritty/kitty necesitan OpenGL)
for t in xfce4-terminal xterm alacritty kitty; do command -v "$t" &>/dev/null && { TERM_CMD="$t"; break; }; done
[[ -n "$TERM_CMD" ]] || { pkg_install xterm; TERM_CMD=xterm; }

# Teclado en X (en el kiosko no corre el autostart de Archcraft que lo ponía)
if [[ "$(localectl status | sed -n 's/^ *X11 Layout: //p')" != "$XKB_LAYOUT" ]]; then
	sudo localectl set-x11-keymap "$XKB_LAYOUT"
	ok "Teclado X: $XKB_LAYOUT"
fi

# Config del kiosko (se regenera siempre)
KDIR="$HOME/.config/kiosko"
mkdir -p "$KDIR"
cp "$FILES"/kiosko/{rc.xml,menu.xml,xinitrc,autostart,relanzar.sh,apagar.sh,login.sh} "$KDIR/"
sed -i -e "s|@TERM@|$TERM_CMD|g" -e "s|@APP@|$APPS_DIR/$KIOSK_APP/run.sh|g" -e "s|@KDIR@|$KDIR|g" "$KDIR"/*
sed -i -e "s|@APPNAME@|$KIOSK_APP|g" "$KDIR"/*
printf "%s\n" "${KIOSK_ENV[@]}" >"$KDIR/env"
chmod +x "$KDIR"/{xinitrc,autostart,relanzar.sh,apagar.sh}
ok "Config en $KDIR (terminal: $TERM_CMD)"

# El shell de login lanza X en tty1 (bash y zsh)
for f in .bash_profile .zprofile; do
	grep -qs 'kiosko/login.sh' "$HOME/$f" || echo "[[ -f \"$KDIR/login.sh\" ]] && . \"$KDIR/login.sh\"" >>"$HOME/$f"
done

# Autologin en tty1
sys_write /etc/systemd/system/getty@tty1.service.d/autologin.conf <<CONF && ok "Autologin de $USER en tty1"
[Service]
ExecStart=
ExecStart=-/sbin/agetty -o '-p -f -- \\\\u' --noclear --autologin $USER %I \$TERM
Type=idle
CONF

# Sin display manager: no hay otra sesión gráfica que la del kiosko (ahorra RAM y arranque)
if [[ -L /etc/systemd/system/display-manager.service ]]; then
	dm="$(basename "$(readlink /etc/systemd/system/display-manager.service)")"
	sudo systemctl disable "$dm" &>/dev/null
	dm_pkg="$(pacman -Qqo "/usr/lib/systemd/system/$dm" 2>/dev/null || true)"
	[[ -n "$dm_pkg" ]] && pkg_remove "$dm_pkg"
	ok "Display manager $dm eliminado (aplica al reiniciar)"
fi

# startx a mano también abre el kiosko, nunca el escritorio de Archcraft
if [[ "$(readlink "$HOME/.xinitrc" 2>/dev/null)" != "$KDIR/xinitrc" ]]; then
	[[ -e "$HOME/.xinitrc" && ! -e "$HOME/.xinitrc.orig" ]] && mv "$HOME/.xinitrc" "$HOME/.xinitrc.orig"
	ln -sf "$KDIR/xinitrc" "$HOME/.xinitrc"
	ok "~/.xinitrc apunta al kiosko"
fi
# Apagar/reiniciar sin contraseña aunque haya otra sesión abierta (p. ej. SSH de mantenimiento)
sys_write /etc/polkit-1/rules.d/49-kiosko-apagar.rules <<RULES && ok "Polkit: $USER puede apagar y reiniciar"
polkit.addRule(function(action, subject) {
	if (subject.user == "$USER" &&
	    /^org\.freedesktop\.login1\.(power-off|reboot)(-multiple-sessions|-ignore-inhibit)?\$/.test(action.id)) {
		return polkit.Result.YES;
	}
});
RULES

sudo systemctl daemon-reload
ok "Kiosko listo"
