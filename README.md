# archcraft-postinstall

Convierte una instalación normal de [Archcraft](https://archcraft.io) en un **kiosko liviano
para equipos lentos** (2 GB de RAM o menos) que corre una sola app a pantalla completa:
[LabSim](https://github.com/Debaq/LabSim), [Kütral](https://github.com/Debaq/kutral) o
[LabNAS](https://github.com/Debaq/labnas).
No hay que mantener una ISO propia: se instala Archcraft de fábrica y después se corre este script.

Resultado medido en una VM con 2 GB de RAM:

| | Archcraft de fábrica | Con el script |
|---|---|---|
| Arranque | no terminaba (esperaba la sincronización de hora) | ~6 s |
| RAM usada | 577 MB (escritorio, sin LabSim) | ~510 MB **con LabSim abierto** |
| Disco | 7,5 GB | 5,1 GB |
| Swap | ninguno | zram (swap comprimido en RAM) |

## Uso

### 1. Instalar Archcraft

Con la ISO oficial y el instalador (Calamares):

- **Escritorio:** Openbox.
- **Gestor de arranque:** GRUB.
- **Usuario:** el que va a usar el kiosko (entra solo, sin contraseña, al prender).

### 2. Correr el script

En el equipo recién instalado, con internet, abrir una terminal y ejecutar:

```bash
git clone https://github.com/Debaq/archcraft-postinstall
cd archcraft-postinstall
./postinstall.sh
```

Primero pregunta **qué app abre el kiosko** (LabSim, Kutral o LabNAS; se recuerda para las próximas
corridas) y después la contraseña de `sudo`, **una sola vez**. Tarda unos minutos (descarga la
app, ~180 MB). Al terminar, **reiniciar**: el equipo arranca directo en la app.

Se puede volver a correr sin problema. Cada vez:

1. **Se actualiza solo** desde git (`git pull`) y, si bajó una versión nueva, se relanza con ella.
   Sin red o con cambios locales, avisa y sigue con la versión que tiene.
2. **Salta los módulos ya hechos:** guarda una huella de cada módulo aplicado en
   `~/.local/state/archcraft-postinstall/`. Un módulo se vuelve a aplicar solo si él, `config.sh`,
   `lib.sh`, `files/` o `diag-audio.sh` cambiaron.
3. **Si un módulo falla, sigue con el resto** y al final muestra el resumen. El que falló se
   reintenta en la próxima corrida.

```bash
./postinstall.sh               # lo nuevo o cambiado
./postinstall.sh --todo        # todos, aunque ya estén hechos
./postinstall.sh --elegir      # vuelve a preguntar la app del kiosko
./postinstall.sh --app=kutral  # cambia la app sin preguntar
./postinstall.sh kiosko        # solo 70-kiosko (siempre)
./postinstall.sh 10 70         # 10-apps y 70-kiosko (siempre)
```

### Actualizar un equipo ya configurado

```bash
cd archcraft-postinstall && ./postinstall.sh
```

### Sin audio

Con el usuario del kiosko (sin `sudo`), desde la terminal del menú o por SSH:

```bash
cd archcraft-postinstall && git pull && ./diag-audio.sh     # o: ./postinstall.sh audio
```

Diagnostica, repara y prueba un tono: reinstala los paquetes de audio y el firmware, quita
PulseAudio si quedó, reinicia PipeWire olvidando la salida elegida y prefiere parlantes o
audífonos sobre HDMI. Todo (antes, reparación, después y si se escuchó el tono) queda en
`~/audio-<hostname>.txt`. `./diag-audio.sh --solo-diag` solo diagnostica. `postinstall.sh` ya
lo corre al final (módulo `80-audio`).

## Cómo se usa el kiosko

- **Al prender:** entra solo y abre LabSim en pantalla completa. No hay escritorio.
- **Apagar:** botón de encendido del equipo. LabSim recibe `SIGTERM` para guardar y salir, y el
  equipo se apaga (espera hasta 15 s). Mantener el botón apretado fuerza el apagado.
- **Si LabSim se cae,** se vuelve a abrir solo en unos segundos.
- **Si un docente cierra LabSim** (salida normal), queda el fondo y con **clic derecho** aparece
  el menú de mantenimiento: LabSim, Archivos, Red / Wi-Fi, Terminal, Reiniciar, Apagar.
  LabSim se reabre solo tras **5 minutos sin tocar teclado ni mouse** (`KIOSK_REOPEN_IDLE`), o
  al elegirlo en el menú.
- **Consola de mantenimiento:** `Ctrl+Alt+F2` (pide usuario y contraseña).
- Con LabSim abierto no hay atajos para abrir otras cosas: el alumno no sale de LabSim.

LabSim se actualiza solo al abrir (queda en `/opt/LabSim`, a nombre del usuario, para que su
actualizador pueda reemplazar archivos).

## Qué hace cada módulo

| Módulo | Qué hace |
|---|---|
| `05-pacman` | Deja las llaves de pacman en disco. Archcraft las hereda de la ISO en memoria y las regenera en cada arranque (lento en CPUs viejas). |
| `10-apps` | Instala la app elegida en `/opt/<app>` con acceso directo. Corre siempre: Kutral no se actualiza sola y aquí baja la versión nueva. |
| `20-memoria` | zram del tamaño de la RAM (zstd) y ajustes de memoria y escritura a disco para poca RAM y HDD. |
| `30-servicios` | Desactiva servicios innecesarios (bluetooth, impresión, avahi, cloud-init, tareas diarias…), DNS por NetworkManager, journal chico, sin volcados de memoria ni watchdog. |
| `40-arranque` | `mitigations=off` y otros parámetros de kernel, GRUB con 1 s de espera, sin initramfs de respaldo. |
| `50-disco` | `noatime` y planificador `bfq` en discos HDD. |
| `60-paquetes` | Quita el escritorio de Archcraft (polybar, picom, rofi…), SDDM, plymouth, apps sin uso, temas, iconos, manuales e idiomas ajenos. |
| `70-kiosko` | Autologin en tty1, X con un Openbox mínimo (sin compositor), la app siempre abierta, volumen fijo, teclado, apagado ordenado. |
| `80-audio` | Corre `diag-audio.sh` (sin tono de prueba): repara el audio y deja el diagnóstico en `~/audio-<hostname>.txt`. |

Los archivos del sistema que se modifican quedan respaldados como `.orig`
(`/etc/fstab.orig`, `/etc/default/grub.orig`, `/etc/mkinitcpio.conf.orig`, `~/.xinitrc.orig`).

> **`mitigations=off`** desactiva las protecciones del kernel contra Spectre/Meltdown a cambio
> de rendimiento en CPUs viejas. Pensado para equipos de laboratorio; se quita en `config.sh`.

## Configuración

Todo lo ajustable está en [`config.sh`](config.sh):

| Variable | Para qué |
|---|---|
| `APP_DEFAULT` | App del kiosko si no se eligió otra (`labsim`); también es la opción por defecto del menú. |
| `KIOSK_VOLUME` | Volumen del sistema al iniciar (%). |
| `KIOSK_REOPEN_IDLE` | Segundos sin uso tras los que se reabre la app si el docente la cerró (300). |
| `XKB_LAYOUT` | Distribución de teclado (`latam`). |
| `KERNEL_PARAMS` / `KERNEL_PARAMS_REMOVE` | Parámetros de kernel que se agregan / quitan. |
| `KEEP_PKGS` | Paquetes que el kiosko necesita: se instalan y nunca se quitan. |
| `REMOVE_PKGS` / `REMOVE_PATTERNS` | Paquetes que se quitan (si otro paquete que se queda los necesita, se saltan con un aviso). |
| `DISABLE_UNITS` | Servicios que se desactivan. |
| `KEEP_LOCALES` | Idiomas que se conservan. |

## Apps del kiosko

Cada app es un archivo en [`apps/`](apps) que define:

| Variable / función | Para qué |
|---|---|
| `APP_NAME` / `APP_DESC` | Nombre (carpeta en `/opt`, menú) y descripción en el menú de elección. |
| `APP_PROC` | Nombre del proceso, para vigilarla (`pgrep -x`) y cerrarla al apagar. |
| `APP_PKGS` | Paquetes que necesita del sistema: se instalan y nunca se quitan. |
| `APP_ENV` | Variables de entorno de la sesión kiosko. |
| `APP_DIR` | Opcional: carpeta de la app (por defecto `/opt/<APP_NAME>`). |
| `APP_WINDOW` | Opcional: atributos de Openbox para reconocer su ventana (`title="…"`), si la app no se pone sola a pantalla completa. |
| `app_install <dest>` | Instala o actualiza en `<dest>`, dejando `<dest>/run.sh`. |
| `app_icon <dest>` | Ruta del ícono para el acceso directo. |

Para agregar otra app basta con otro archivo en `apps/`: aparece sola en el menú.

**LabSim** (`apps/labsim.sh`): tar de PyInstaller; se actualiza sola.

- `LABSIM_KIOSKO=1`: modo laboratorio (pantalla completa, solo un docente puede salir).
- `LABSIM_AUTO_UPDATE=1`: se actualiza sin preguntar.

**Kutral** (`apps/kutral.sh`): binario suelto del release más `vendor/` (yt-dlp, uosc y los
`.conf` de mpv del mismo tag, como `src-tauri/vendor/fetch.sh`); usa el mpv, WebKitGTK y GTK3 del
sistema. No se actualiza sola: `10-apps` baja el release nuevo en cada corrida.

- `KUTRAL_OS=1`: modo equipo dedicado (wifi, brillo, volumen y apagado desde la app).
- `WEBKIT_DISABLE_DMABUF_RENDERER=1`: evita la ventana en blanco de WebKitGTK en GPUs viejas.

**LabNAS** (`apps/labnas.sh`): el equipo pasa a ser el servidor, instalado con el `install.sh`
oficial del release (`--user <usuario del kiosko>`): `/opt/labnas`, servicio `labnas` sin root con
`CAP_NET_RAW` y `CAP_NET_BIND_SERVICE` (`http://<equipo>:3001`). Corre con el usuario del kiosko
para que mpv suene en su sesión, la terminal web abra su shell y vea su home. Se instala una vez y
después se actualiza desde su web. El kiosko muestra la UI con `labnas-viewer` (`/opt/labnas-viewer`,
checksum verificado, pantalla completa por regla de Openbox), que se actualiza en cada corrida. El
servicio sigue activo aunque después se elija otra app. Ojo: el kiosko desactiva `cups` y `avahi`,
así que la impresión de documentos de LabNAS no anda sin reactivarlos.

Lo que cualquier app recibe del kiosko:

- `SIGTERM` al apagar: debe guardar lo que tenga abierto y salir.
- Salida con código 0 = la cerró el usuario (se reabre tras `KIOSK_REOPEN_IDLE` s sin uso); cualquier
  otro código = caída (se reabre enseguida).
- Volumen del sistema fijo: los niveles los maneja la app.

## Probar cambios en una VM

`vm.sh` maneja una VM de pruebas con libvirt en modo usuario (sin root). Los discos y la ISO
quedan en `vm/` (fuera de git).

```bash
./vm.sh iso           # descarga la ISO de Archcraft (retoma si se corta)
./vm.sh create        # crea la VM (4 CPU, 4 GB de RAM para instalar) y arranca la ISO
./vm.sh console       # pantalla, para instalar con Calamares
./vm.sh eject         # tras instalar y apagar: saca la ISO
./vm.sh start
```

Dentro de la VM, activar SSH (`sudo systemctl enable --now sshd`) y luego desde el equipo:

```bash
VM_PASS=<contraseña> ./vm.sh key   # copia la clave SSH
./vm.sh base                       # guarda la instalación limpia
VM_PASS=<contraseña> ./vm.sh run   # copia el proyecto y corre postinstall.sh en la VM
./vm.sh reset                      # vuelve a la instalación limpia
./vm.sh ssh [comando]
```

Notas de la VM:

- Video `qxl`: con `virtio` la pantalla queda negra al arrancar la ISO; con `vga` el escritorio
  de Archcraft se traba.
- En el live, si las ventanas no se dibujan, ejecutar `pkill picom` (el compositor necesita
  aceleración 3D que la VM no tiene).
- Para probar como en los equipos reales, bajar la RAM a 2 GB después de instalar
  (`virsh -c qemu:///session setmaxmem archcraft 2G --config`).
- `vm-type.sh "texto"` escribe en la VM por teclado virtual cuando todavía no hay SSH
  (`LAYOUT=us` en la ISO live, `latam` en el sistema instalado).
