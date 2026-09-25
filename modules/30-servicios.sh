# Desactiva servicios que no hacen falta en el kiosko.

# Se enmascaran: algunos paquetes los activan desde /usr/lib y "disable" no alcanza.
# (Los que son archivos sueltos en /etc no se pueden enmascarar; ahí basta disable.)
for u in "${DISABLE_UNITS[@]}"; do
	unit_exists "$u" || continue
	state="$(systemctl is-enabled "$u" 2>/dev/null || true)"
	[[ "$state" == masked ]] && continue
	# Restos sueltos en /etc no se enmascaran: basta con que estén apagados
	if [[ "$(systemctl show -P FragmentPath "$u")" == /etc/* ]]; then
		[[ "$state" != enabled* ]] && ! systemctl is-active -q "$u" && continue
	fi
	sudo systemctl disable --now "$u" &>/dev/null || true
	sudo systemctl mask "$u" &>/dev/null || true
	ok "Desactivado $u"
done

# DNS directo con NetworkManager (sin systemd-resolved)
if systemctl is-enabled -q systemd-resolved.service 2>/dev/null; then
	sys_write /etc/NetworkManager/conf.d/dns.conf <<'CONF'
[main]
dns=default
rc-manager=file
CONF
	sudo systemctl disable --now systemd-resolved.service &>/dev/null
	[[ -L /etc/resolv.conf ]] && sudo rm /etc/resolv.conf
	sudo systemctl restart NetworkManager
	ok "DNS por NetworkManager (systemd-resolved desactivado)"
fi

# Sin volcados de memoria (ahorran disco y tiempo tras un crash)
sys_write /etc/systemd/coredump.conf.d/kiosko.conf <<'CONF' && ok "Coredumps desactivados"
[Coredump]
Storage=none
ProcessSizeMax=0
CONF

# Journal chico
sys_write /etc/systemd/journald.conf.d/kiosko.conf <<'CONF' && { sudo systemctl restart systemd-journald; ok "Journal limitado a 50M"; }
[Journal]
SystemMaxUse=50M
CONF

# Sin watchdog de hardware (acompaña a nowatchdog)
sys_write /etc/modprobe.d/nowatchdog.conf <<'CONF' && ok "Watchdog en lista negra"
blacklist iTCO_wdt
blacklist sp5100_tco
CONF
ok "Servicios listos"
