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

# Lo que se conserva no se quita aunque esté en REMOVE_PKGS (p. ej. dunst, que LabNAS usa para notificar)
remove=()
for p in "${REMOVE_PKGS[@]}"; do [[ " ${KEEP_PKGS[*]} " == *" $p "* ]] || remove+=("$p"); done
mapfile -t by_pattern < <(for re in "${REMOVE_PATTERNS[@]}"; do pacman -Qq | grep -E "$re"; done)
pkg_remove "${remove[@]}" "${by_pattern[@]}"

# GTK con el tema de fábrica (los de Archcraft ya no están)
mkdir -p "$HOME/.config/gtk-3.0"
cat >"$HOME/.config/gtk-3.0/settings.ini" <<'INI'
[Settings]
gtk-theme-name=Adwaita
gtk-icon-theme-name=Adwaita
gtk-cursor-theme-name=Adwaita
INI

# Sin manuales, documentación ni idiomas ajenos, ahora y en futuras actualizaciones
keep=""
for l in "${KEEP_LOCALES[@]}"; do keep+=" !usr/share/locale/$l* !usr/share/locale/${l}_*"; done
noextract="NoExtract = usr/share/man/* usr/share/doc/* usr/share/help/* usr/share/gtk-doc/* usr/share/info/* usr/share/locale/*$keep !usr/share/locale/locale.alias"
if ! grep -qxF "$noextract" /etc/pacman.conf; then
	sudo sed -i '/^NoExtract = usr\/share\/man/d' /etc/pacman.conf
	sudo sed -i "/^\[options\]/a $noextract" /etc/pacman.conf
	sudo rm -rf /usr/share/{man,doc,help,gtk-doc,info}/*
	find /usr/share/locale -mindepth 1 -maxdepth 1 -type d | while read -r d; do
		n="$(basename "$d")" k=0
		for l in "${KEEP_LOCALES[@]}"; do [[ "$n" == "$l" || "$n" == "$l"_* || "$n" == "$l"@* ]] && k=1; done
		((k)) || sudo rm -rf "$d"
	done
	ok "Sin man/doc ni idiomas ajenos (NoExtract en pacman.conf)"
fi

if ((plymouth_hook)); then
	sudo mkinitcpio -P &>/dev/null && ok "initramfs regenerado sin plymouth"
fi

yes | sudo pacman -Scc &>/dev/null || true
ok "Paquetes limpios"
