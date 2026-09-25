# Deja pacman listo antes de instalar o quitar nada.

# Llaves de pacman en disco. Archcraft hereda de la ISO (archivos sueltos en
# /etc/systemd/system, sin paquete) un keyring en tmpfs que pacman-init regenera en
# cada arranque: gpg crea una llave nueva cada vez, lento en CPUs viejas.
iso_units=(/etc/systemd/system/pacman-init.service /etc/systemd/system/etc-pacman.d-gnupg.mount)
if ls "${iso_units[@]}" &>/dev/null || mountpoint -q /etc/pacman.d/gnupg; then
	# Si pacman-init todavía está generando llaves (recién arrancado), esperar a que termine
	while [[ "$(systemctl is-active pacman-init.service 2>/dev/null)" == activating ]]; do sleep 2; done
	sudo systemctl disable pacman-init.service &>/dev/null || true
	sudo rm -f "${iso_units[@]}"
	sudo systemctl daemon-reload
	if mountpoint -q /etc/pacman.d/gnupg; then
		sudo gpgconf --homedir /etc/pacman.d/gnupg --kill all 2>/dev/null || true
		sudo umount -l /etc/pacman.d/gnupg
	fi
	ok "Keyring de pacman en disco (sin tmpfs ni pacman-init)"
fi
if ! sudo test -s /etc/pacman.d/gnupg/pubring.gpg; then
	sudo pacman-key --init &>/dev/null
	sudo pacman-key --populate &>/dev/null
	ok "Keyring de pacman inicializado"
fi
ok "Pacman listo"
