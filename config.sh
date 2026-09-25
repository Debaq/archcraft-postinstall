# Configuración del post-install. Se carga antes de cada módulo.

# Apps del kiosko: una por archivo en apps/ (nombre, paquetes, variables y cómo se instala).
# postinstall.sh pregunta cuál abre el kiosko y lo recuerda; solo esa se instala.
APPS_DIR=/opt
APP_DEFAULT=labsim # la que se usa sin elección guardada (y la opción por defecto del menú)

# Parámetros de kernel extra (mitigations=off: más rendimiento en CPUs viejas, menos seguridad)
KERNEL_PARAMS=(mitigations=off nowatchdog zswap.enabled=0 quiet loglevel=3)
# Parámetros que se quitan (splash: pantalla de plymouth, que se desinstala)
KERNEL_PARAMS_REMOVE=(splash)

# Distribución de teclado en X (la consola ya la trae del instalador)
XKB_LAYOUT=latam

# Audio: PipeWire con las capas ALSA/Pulse y el firmware/perfiles de tarjetas nuevas
# (sof-firmware: Intel desde ~2018; alsa-ucm-conf: perfiles de esas tarjetas).
# diag-audio.sh reinstala esta misma lista al reparar.
AUDIO_PKGS=(
	pipewire pipewire-pulse pipewire-alsa wireplumber
	rtkit # audio en tiempo real, sin cortes con CPU cargada
	alsa-utils alsa-ucm-conf alsa-firmware sof-firmware
)

# Paquetes que el kiosko necesita: se instalan antes de limpiar y se marcan como explícitos
# para que "pacman -Rns" no los arrastre al quitar el escritorio de Archcraft.
KEEP_PKGS=(
	xorg-server xorg-xinit xorg-xset xorg-xsetroot openbox
	thunar thunar-volman thunar-archive-plugin xfce4-terminal atril nm-connection-editor
	networkmanager "${AUDIO_PKGS[@]}"
	xprintidle # relanzar.sh: reabre la app tras un rato sin uso
)

# Paquetes que se eliminan si están instalados
REMOVE_PKGS=(
	# Escritorio de Archcraft: sin él no existe sesión normal
	archcraft-openbox archcraft-openbox-themes obconf-qt obmenu-generator
	polybar rofi nitrogen dunst archcraft-dunst-icons picom plank pulsemixer python-pywal light pastel
	betterlockscreen i3lock-color xfce4-power-manager archcraft-randr archcraft-arandr wdisplays
	archcraft-about archcraft-help archcraft-artworks archcraft-backgrounds archcraft-backgrounds-branding
	archcraft-funscripts archcraft-neofetch
	archcraft-music archcraft-config-music mpd ncmpcpp archcraft-ranger ranger
	# Pantalla de login y de arranque
	archcraft-sddm-theme sddm archcraft-plymouth-theme plymouth
	# Apps que no se usan (alacritty y kitty necesitan OpenGL)
	firefox alacritty kitty archcraft-config-geany geany geany-plugins meld galculator catfish viewnior
	timeshift btrfs-assistant clonezilla gufw thunar-shares-plugin thunar-media-tags-plugin
	# Servicios de nube/virtualización y hardware que no existe en el laboratorio
	cloud-init hyperv qemu-guest-agent linux-atm b43-fwcutter
	# Desarrollo de Xorg y fuentes asiáticas (~300 MB)
	xorg-server-devel xorg-server-src xorg-server-xvfb noto-fonts-cjk
)
# Patrones (regex sobre el nombre) que también se eliminan: temas, iconos y cursores
# de Archcraft (~1,7 GB). GTK queda con Adwaita.
REMOVE_PATTERNS=('^archcraft-(gtk-theme|icons|cursor)-')

# Idiomas que se conservan en /usr/share/locale (el resto, y man/doc, se borra y
# pacman deja de instalarlos con NoExtract)
KEEP_LOCALES=(es en)

# Servicios que se desactivan si existen
DISABLE_UNITS=(
	bluetooth.service
	cups.service cups.socket cups.path
	avahi-daemon.service avahi-daemon.socket
	ModemManager.service
	NetworkManager-wait-online.service
	reflector.service reflector.timer
	pcscd.socket systemd-time-wait-sync.service
	choose-mirror.service
	apparmor.service
	man-db.timer # reconstruye el índice de man a diario: tirones en HDD
	systemd-userdbd.socket systemd-userdbd.service
)

# Volumen del sistema al iniciar la sesión (%). La app maneja los niveles: el sistema va fijo.
KIOSK_VOLUME=100

# Si el docente cierra la app, se reabre sola tras estos segundos sin tocar teclado ni mouse
# (mientras, queda el menú de mantenimiento con clic derecho).
KIOSK_REOPEN_IDLE=300
