# Quita paquetes innecesarios y limpia la caché de pacman.

# plymouth se va: sacar su hook del initramfs antes, o mkinitcpio falla
plymouth_hook=0
if grep -qE '^HOOKS=.*\bplymouth\b' /etc/mkinitcpio.conf && [[ " ${REMOVE_PKGS[*]} " == *" plymouth "* ]]; then
	[[ -e /etc/mkinitcpio.conf.orig ]] || sudo cp -a /etc/mkinitcpio.conf /etc/mkinitcpio.conf.orig
	sudo sed -i -E '/^HOOKS=/ s/ ?\bplymouth\b//' /etc/mkinitcpio.conf
	plymouth_hook=1
fi

# Lo que se conserva queda instalado y marcado explícito antes de quitar nada
pkg_install "${KEEP_PKGS[@]}"
sudo pacman -D --asexplicit "${KEEP_PKGS[@]}" >/dev/null

pkg_remove "${REMOVE_PKGS[@]}"

if ((plymouth_hook)); then
	sudo mkinitcpio -P &>/dev/null && ok "initramfs regenerado sin plymouth"
fi

yes | sudo pacman -Scc &>/dev/null || true
ok "Paquetes limpios"
