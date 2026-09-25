# Parámetros de kernel y arranque rápido de GRUB.

if [[ ! -f /etc/default/grub ]]; then
	warn "No hay /etc/default/grub; agrega a mano: ${KERNEL_PARAMS[*]}"
	return 0
fi

changed=0

# Sin initramfs "fallback": las actualizaciones de kernel tardan la mitad
for preset in /etc/mkinitcpio.d/*.preset; do
	[[ -f "$preset" ]] || continue
	if grep -q "^PRESETS=('default' 'fallback')" "$preset"; then
		sudo sed -i "s/^PRESETS=('default' 'fallback')/PRESETS=('default')/" "$preset"
		sudo rm -f /boot/initramfs-*-fallback.img
		changed=1
		ok "Sin initramfs fallback ($(basename "$preset"))"
	fi
done

# Archcraft usa comillas simples; se aceptan ambas
current="$(sed -nE "s/^GRUB_CMDLINE_LINUX_DEFAULT=[\"'](.*)[\"']$/\1/p" /etc/default/grub)"
read -ra words <<<"$current"
new=()
for w in "${words[@]}"; do
	key="${w%%=*}" drop=0
	for p in "${KERNEL_PARAMS[@]}"; do [[ "${p%%=*}" == "$key" ]] && drop=1; done
	for p in "${KERNEL_PARAMS_REMOVE[@]}"; do [[ "$p" == "$key" ]] && drop=1; done
	# evita duplicados
	[[ " ${new[*]} " == *" $w "* ]] && drop=1
	((drop)) || new+=("$w")
done
new+=("${KERNEL_PARAMS[@]}")
new="${new[*]}"

if [[ "$new" != "$current" ]]; then
	[[ -e /etc/default/grub.orig ]] || sudo cp -a /etc/default/grub /etc/default/grub.orig
	sudo sed -i "s|^GRUB_CMDLINE_LINUX_DEFAULT=.*|GRUB_CMDLINE_LINUX_DEFAULT=\"$new\"|" /etc/default/grub
	changed=1
fi
if ! grep -q '^GRUB_TIMEOUT=1$' /etc/default/grub; then
	sudo sed -i 's/^GRUB_TIMEOUT=.*/GRUB_TIMEOUT=1/' /etc/default/grub
	changed=1
fi
# Menú oculto (Esc durante ese segundo lo muestra) y sin el tema de Archcraft, que 60-paquetes
# quita: dibujar el tema (imágenes y fuentes) tarda en equipos viejos
if ! grep -q '^GRUB_TIMEOUT_STYLE=hidden$' /etc/default/grub || grep -q '^GRUB_THEME=' /etc/default/grub; then
	[[ -e /etc/default/grub.orig ]] || sudo cp -a /etc/default/grub /etc/default/grub.orig
	sudo sed -i -e '/^GRUB_TIMEOUT_STYLE=/d' -e '/^GRUB_THEME=/d' /etc/default/grub
	echo 'GRUB_TIMEOUT_STYLE=hidden' | sudo tee -a /etc/default/grub >/dev/null
	changed=1
fi

if ((changed)); then
	sudo grub-mkconfig -o /boot/grub/grub.cfg &>/dev/null
	ok "GRUB: $new (aplica al reiniciar)"
else
	ok "GRUB ya configurado"
fi
