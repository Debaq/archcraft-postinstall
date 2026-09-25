# Desactiva servicios que no hacen falta en el kiosko.

for u in "${DISABLE_UNITS[@]}"; do
	unit_exists "$u" || continue
	if systemctl is-enabled -q "$u" 2>/dev/null || systemctl is-active -q "$u"; then
		sudo systemctl disable --now "$u" &>/dev/null && ok "Desactivado $u"
	fi
done

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
