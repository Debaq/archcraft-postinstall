# postinstall: siempre (detecta el hardware: si el disco pasa a otro equipo, se ajusta solo)
# Ajustes según el procesador y la GPU del equipo: microcódigo, video por hardware,
# firmware que no se usa, CPU a máxima frecuencia en equipos de escritorio y earlyoom.
# Quitar o instalar microcódigo y firmware regenera initramfs y GRUB solo (hooks de pacman).

# Vendors PCI presentes (0x8086 Intel, 0x1002 AMD, 0x10de NVIDIA, 0x11ab/0x1b4b Marvell);
# gpus: solo los de clase 0x03 (pantalla)
declare -A gpus=() pcis=()
for d in /sys/bus/pci/devices/*; do
	v="$(<"$d/vendor")"
	pcis[$v]=1
	[[ "$(<"$d/class")" == 0x03* ]] && gpus[$v]=1
done

# Microcódigo solo del fabricante de la CPU
case "$(sed -n 's/^vendor_id\s*: //p;T;q' /proc/cpuinfo)" in
GenuineIntel) ucode=intel-ucode other=amd-ucode ;;
AuthenticAMD) ucode=amd-ucode other=intel-ucode ;;
*) ucode="" other="" ;;
esac
if [[ -n "$ucode" ]]; then
	pkg_install "$ucode"
	sudo pacman -D --asexplicit "$ucode" >/dev/null
	pkg_remove "$other"
	ok "Microcódigo: $ucode"
fi

# Video por hardware (VA-API): mpv (Kutral, LabNAS) decodifica en la GPU y no en la CPU.
# Intel: iHD desde Broadwell (2014), i965 las anteriores; libva prueba ambos. AMD y NVIDIA: en mesa.
if [[ -n "${gpus[0x8086]:-}" ]]; then
	pkg_install intel-media-driver libva-intel-driver
	ok "VA-API de Intel"
fi

# Firmware: fuera el de servidores y el de GPU/red que el equipo no tiene. Se queda el de wifi,
# bluetooth y audio (intel, realtek, atheros, broadcom, mediatek…) aunque no esté: puede
# enchufarse un adaptador USB. El metapaquete linux-firmware arrastra todos: también se va.
fw_remove=("${FIRMWARE_REMOVE[@]}")
[[ -n "${gpus[0x10de]:-}" ]] || fw_remove+=(linux-firmware-nvidia)
[[ -n "${gpus[0x1002]:-}" ]] || fw_remove+=(linux-firmware-amdgpu linux-firmware-radeon)
[[ -n "${pcis[0x11ab]:-}${pcis[0x1b4b]:-}" ]] || lsusb 2>/dev/null | grep -q ' ID 1286:' || fw_remove+=(linux-firmware-marvell)
mapfile -t fw_keep < <(pacman -Qq | grep -E '^linux-firmware-' | grep -vxF -f <(printf '%s\n' "${fw_remove[@]}"))
# Explícitos: si no, "pacman -Rns linux-firmware" se los lleva como dependencias huérfanas
((${#fw_keep[@]})) && sudo pacman -D --asexplicit "${fw_keep[@]}" >/dev/null
[[ -n "$(pacman -Qq "${fw_remove[@]}" 2>/dev/null)" ]] && pkg_remove linux-firmware mkinitcpio-firmware "${fw_remove[@]}"
ok "Firmware: $(du -sh /usr/lib/firmware | cut -f1)"

# Headers del kernel: solo sirven para compilar módulos (dkms), que el kiosko no usa
if ! pacman -Qq dkms &>/dev/null; then
	mapfile -t headers < <(pacman -Qq | grep -E '^linux.*-headers$' | grep -v '^linux-api-headers$' || true)
	((${#headers[@]})) && pkg_remove "${headers[@]}"
fi

# CPU a máxima frecuencia en equipos sin batería (no en notebooks ni VMs): la interfaz responde
# sin esperar a que suba la frecuencia. Los estados de reposo (C-states) siguen igual.
# Se aplica al arrancar, cuando ya cargó el driver de frecuencia (acpi-cpufreq, intel_pstate…).
if ! compgen -G '/sys/class/power_supply/BAT*' >/dev/null && ! systemd-detect-virt -q; then
	sys_write /etc/systemd/system/cpu-performance.service <<'UNIT' && { sudo systemctl daemon-reload; sudo systemctl enable -q --now cpu-performance.service; ok "CPU en modo performance"; }
[Unit]
Description=CPU a máxima frecuencia (kiosko)
After=systemd-modules-load.service

[Service]
Type=oneshot
# El driver (módulo) puede cargar después de arrancar este servicio: espera hasta 20 s
ExecStart=/bin/sh -c 'for i in $$(seq 20); do [ -e /sys/devices/system/cpu/cpu0/cpufreq ] && break; sleep 1; done; for g in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do echo performance >"$$g"; done; true'

[Install]
WantedBy=multi-user.target
UNIT
elif [[ -e /etc/systemd/system/cpu-performance.service ]]; then
	sudo systemctl disable -q cpu-performance.service
	sudo rm /etc/systemd/system/cpu-performance.service
	sudo systemctl daemon-reload
	ok "CPU con la frecuencia de fábrica (notebook o VM)"
fi

# earlyoom: sin memoria, cierra el proceso más grande (la app, que el kiosko reabre) antes
# de que el equipo se congele intercambiando con zram
pkg_install earlyoom
sys_write /etc/default/earlyoom <<CONF && sudo systemctl restart earlyoom.service
EARLYOOM_ARGS="$EARLYOOM_ARGS"
CONF
sudo systemctl enable -q --now earlyoom.service
ok "earlyoom activo"
ok "Hardware listo"
