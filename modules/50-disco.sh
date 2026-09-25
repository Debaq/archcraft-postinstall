# Menos escrituras y mejor planificador de E/S (clave en discos HDD).

# noatime en particiones ext4/btrfs/xfs (reemplaza relatime o lo agrega a "defaults")
fstab_new="$(awk '!/^[[:space:]]*#/ && ($3=="ext4"||$3=="btrfs"||$3=="xfs") && $4 !~ /(^|,)noatime(,|$)/ {
	if ($4 ~ /(^|,)relatime(,|$)/) sub(/relatime/, "noatime", $4); else $4 = $4 ",noatime"
} {print}' OFS='\t' /etc/fstab)"
if [[ "$fstab_new" != "$(cat /etc/fstab)" ]]; then
	[[ -e /etc/fstab.orig ]] || sudo cp -a /etc/fstab /etc/fstab.orig
	sudo tee /etc/fstab >/dev/null <<<"$fstab_new"
	sudo systemctl daemon-reload
	ok "fstab con noatime (aplica al reiniciar)"
else
	ok "fstab ya con noatime"
fi

# HDD: bfq (mejor respuesta interactiva); SSD/NVMe: sin cambios
sys_write /etc/udev/rules.d/60-ioscheduler.rules <<'CONF' && ok "Planificador bfq para HDD"
ACTION=="add|change", KERNEL=="sd[a-z]*|mmcblk[0-9]*", ATTR{queue/rotational}=="1", ATTR{queue/scheduler}="bfq"
CONF

unit_exists fstrim.timer && sudo systemctl enable -q fstrim.timer
ok "Disco listo"
