# archcraft-postinstall

Convierte una instalación normal de [Archcraft](https://archcraft.io) en un **kiosko liviano
para equipos lentos** (2 GB de RAM o menos) que solo corre [LabSim](https://github.com/Debaq/LabSim).
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

Pide la contraseña de `sudo` **una sola vez**. Tarda unos minutos (descarga LabSim, ~180 MB).
Al terminar, **reiniciar**: el equipo arranca directo en LabSim.

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
- **Si un docente cierra LabSim** (salida normal), no se reabre: queda el fondo y con **clic
  derecho** aparece el menú de mantenimiento: LabSim, Archivos, Red / Wi-Fi, Terminal,
  Reiniciar, Apagar.
- **Consola de mantenimiento:** `Ctrl+Alt+F2` (pide usuario y contraseña).
- Con LabSim abierto no hay atajos para abrir otras cosas: el alumno no sale de LabSim.

LabSim se actualiza solo al abrir (queda en `/opt/LabSim`, a nombre del usuario, para que su
actualizador pueda reemplazar archivos).

## Qué hace cada módulo

| Módulo | Qué hace |
|---|---|
| `05-pacman` | Deja las llaves de pacman en disco. Archcraft las hereda de la ISO en memoria y las regenera en cada arranque (lento en CPUs viejas). |
| `10-apps` | Instala las apps de `APPS` desde GitHub Releases en `/opt`, con acceso directo. |
| `20-memoria` | zram del tamaño de la RAM (zstd) y ajustes de memoria y escritura a disco para poca RAM y HDD. |
| `30-servicios` | Desactiva servicios innecesarios (bluetooth, impresión, avahi, cloud-init, tareas diarias…), DNS por NetworkManager, journal chico, sin volcados de memoria ni watchdog. |
| `40-arranque` | `mitigations=off` y otros parámetros de kernel, GRUB con 1 s de espera, sin initramfs de respaldo. |
| `50-disco` | `noatime` y planificador `bfq` en discos HDD. |
| `60-paquetes` | Quita el escritorio de Archcraft (polybar, picom, rofi…), SDDM, plymouth, apps sin uso, temas, iconos, manuales e idiomas ajenos. |
| `70-kiosko` | Autologin en tty1, X con un Openbox mínimo (sin compositor), LabSim siempre abierto, volumen fijo, teclado, apagado ordenado. |
| `80-audio` | Corre `diag-audio.sh` (sin tono de prueba): repara el audio y deja el diagnóstico en `~/audio-<hostname>.txt`. |

Los archivos del sistema que se modifican quedan respaldados como `.orig`
(`/etc/fstab.orig`, `/etc/default/grub.orig`, `/etc/mkinitcpio.conf.orig`, `~/.xinitrc.orig`).

> **`mitigations=off`** desactiva las protecciones del kernel contra Spectre/Meltdown a cambio
> de rendimiento en CPUs viejas. Pensado para equipos de laboratorio; se quita en `config.sh`.

## Configuración

Todo lo ajustable está en [`config.sh`](config.sh):

| Variable | Para qué |
|---|---|
| `APPS` | Apps a instalar desde GitHub Releases: `"nombre\|repo\|prefijo_tag\|asset.tar.gz"`. El tar debe traer una carpeta `nombre/` con el ejecutable `nombre` y un `run.sh`. |
| `KIOSK_APP` | App que abre el kiosko y mantiene abierta. |
| `KIOSK_ENV` | Variables de entorno de la sesión kiosko (`LABSIM_KIOSKO=1`, `LABSIM_AUTO_UPDATE=1`). |
| `KIOSK_VOLUME` | Volumen del sistema al iniciar (%). |
| `XKB_LAYOUT` | Distribución de teclado (`latam`). |
| `KERNEL_PARAMS` / `KERNEL_PARAMS_REMOVE` | Parámetros de kernel que se agregan / quitan. |
| `KEEP_PKGS` | Paquetes que el kiosko necesita: se instalan y nunca se quitan. |
| `REMOVE_PKGS` / `REMOVE_PATTERNS` | Paquetes que se quitan (si otro paquete que se queda los necesita, se saltan con un aviso). |
| `DISABLE_UNITS` | Servicios que se desactivan. |
| `KEEP_LOCALES` | Idiomas que se conservan. |

## Lo que LabSim recibe del kiosko

- `LABSIM_KIOSKO=1`: modo laboratorio (pantalla completa, solo un docente puede salir).
- `LABSIM_AUTO_UPDATE=1`: se actualiza sin preguntar.
- `SIGTERM` al apagar: debe guardar informes y logs y salir, aunque no haya docente logueado.
- Salida con código 0 = la cerró un docente (no se reabre); cualquier otro código = caída (se reabre).
- Volumen del sistema fijo: los niveles los maneja LabSim.

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
