# Arranca X en tty1 al hacer login (autologin). En otras tty queda la consola normal.
if [[ -z "$DISPLAY" && "$XDG_VTNR" == 1 ]]; then
	exec startx "@KDIR@/xinitrc" -- -nolisten tcp -keeptty >"$HOME/.cache/kiosko-x.log" 2>&1
fi
