# zram (swap comprimido en RAM) + sysctl para equipos con poca memoria.

pkg_install zram-generator

sys_write /etc/systemd/zram-generator.conf <<'CONF' && { sudo systemctl daemon-reload; sudo systemctl start systemd-zram-setup@zram0.service; ok "zram configurado"; }
[zram0]
zram-size = ram
compression-algorithm = zstd
swap-priority = 100
CONF

# Valores recomendados para zram (ArchWiki / Pop!_OS)
sys_write /etc/sysctl.d/99-memoria.conf <<'CONF' && { sudo sysctl -q --system; ok "sysctl de memoria aplicado"; }
vm.swappiness = 180
vm.watermark_boost_factor = 0
vm.watermark_scale_factor = 125
vm.page-cluster = 0
vm.vfs_cache_pressure = 50
# Escribir a disco en tramos chicos: en HDD con poca RAM evita congelones
vm.dirty_background_bytes = 16777216
vm.dirty_bytes = 50331648
CONF
ok "Memoria lista"
