#!/usr/bin/env bash
# Helper para la VM de pruebas (libvirt en modo sesión, sin root).
# Uso: ./vm.sh <comando> [args]
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
VMDIR="$ROOT/vm"
NAME="archcraft"
ISO="$(ls "$VMDIR"/archcraft-*.iso 2>/dev/null | sort | tail -1 || true)"
DISK="$VMDIR/disk.qcow2"
BASE="$VMDIR/base.qcow2"
KEY="$VMDIR/id_ed25519"
SSH_PORT=2222
VM_USER="${VM_USER:-nick}"
CONN="qemu:///session"

virsh() { command virsh -c "$CONN" "$@"; }
ssh_opts=(-p "$SSH_PORT" -i "$KEY" -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR)
nvram() { virsh dumpxml "$NAME" | sed -n 's:.*<nvram[^>]*>\(.*\)</nvram>.*:\1:p'; }

wait_off() {
	for _ in $(seq 60); do
		[[ "$(virsh domstate "$NAME")" == "apagado" || "$(virsh domstate "$NAME")" == "shut off" ]] && return 0
		sleep 2
	done
	echo "La VM no se apagó; forzando" >&2
	virsh destroy "$NAME"
}

case "${1:-help}" in
iso)
	# Descarga (o retoma) la ISO; queda como .part hasta completarse
	url="https://downloads.sourceforge.net/project/archcraft/v26.08/archcraft-2026.08.01-x86_64.iso"
	part="$VMDIR/$(basename "$url").part"
	curl -L --fail -C - -o "$part" "$url"
	mv "$part" "${part%.part}"
	;;
create)
	[[ -n "$ISO" ]] || { echo "No hay ISO en $VMDIR" >&2; exit 1; }
	[[ -f "$DISK" ]] || qemu-img create -f qcow2 "$DISK" 40G
	virt-install --connect "$CONN" \
		--name "$NAME" --osinfo archlinux \
		--vcpus 4 --memory 4096 \
		--boot uefi,cdrom,hd,firmware.feature0.name=secure-boot,firmware.feature0.enabled=no \
		--disk "path=$DISK,format=qcow2,bus=virtio" \
		--disk "path=$ISO,device=cdrom,bus=sata" \
		--import \
		--network "passt,portForward=$SSH_PORT:22" \
		--graphics spice --video vga \
		--noautoconsole
	;;
eject)
	# Tras instalar: saca la ISO y arranca desde el disco
	command virt-xml --connect "$CONN" "$NAME" --edit target.dev=sda --disk path= >/dev/null
	command virt-xml --connect "$CONN" "$NAME" --edit --boot hd >/dev/null
	echo "ISO retirada; la VM arranca desde el disco."
	;;
console) virt-manager -c "$CONN" --show-domain-console "$NAME" ;;
start) virsh start "$NAME" ;;
stop) virsh shutdown "$NAME"; wait_off ;;
key)
	# Instala la clave dedicada en la VM (pide la contraseña del usuario una vez)
	[[ -f "$KEY" ]] || ssh-keygen -q -t ed25519 -N "" -C "archcraft-vm" -f "$KEY"
	# Con VM_PASS definido no pregunta la contraseña (ssh la toma de un askpass temporal)
	if [[ -n "${VM_PASS:-}" ]]; then
		askpass="$(mktemp)"; printf '#!/bin/sh\necho "$VM_PASS"\n' >"$askpass"; chmod 700 "$askpass"
		export VM_PASS SSH_ASKPASS="$askpass" SSH_ASKPASS_REQUIRE=force
	fi
	ssh -p "$SSH_PORT" -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR \
		-o PubkeyAuthentication=no "$VM_USER@localhost" \
		'umask 077; mkdir -p ~/.ssh; k="$(cat)"; grep -qxF "$k" ~/.ssh/authorized_keys 2>/dev/null || echo "$k" >>~/.ssh/authorized_keys' <"$KEY.pub"
	rm -f "${askpass:-}"
	echo "Clave instalada."
	;;
ssh) shift; ssh "${ssh_opts[@]}" -t "$VM_USER@localhost" "$@" ;;
push)
	# Copia el proyecto (sin vm/) a ~/archcraft-postinstall en la VM
	rsync -a --delete --exclude vm/ --exclude .git/ -e "ssh ${ssh_opts[*]}" "$ROOT/" "$VM_USER@localhost:archcraft-postinstall/"
	;;
run)
	shift
	"$0" push
	# Con VM_PASS no pide la contraseña de sudo (útil sin terminal interactiva)
	ssh "${ssh_opts[@]}" -t "$VM_USER@localhost" "cd archcraft-postinstall && ${VM_PASS:+SUDO_PASS='$VM_PASS' }./postinstall.sh $*"
	;;
base)
	# Congela el disco actual como base limpia; en adelante se trabaja sobre un overlay
	[[ ! -f "$BASE" ]] || { echo "Ya existe $BASE" >&2; exit 1; }
	virsh domstate "$NAME" | grep -qiE 'apagado|shut off' || { virsh shutdown "$NAME"; wait_off; }
	mv "$DISK" "$BASE"
	chmod a-w "$BASE"
	cp "$(nvram)" "$VMDIR/base_VARS.fd"
	qemu-img create -q -f qcow2 -b "$BASE" -F qcow2 "$DISK"
	echo "Base guardada. './vm.sh reset' vuelve a este estado."
	;;
reset)
	[[ -f "$BASE" ]] || { echo "No hay base; ejecuta './vm.sh base' primero" >&2; exit 1; }
	virsh domstate "$NAME" | grep -qiE 'apagado|shut off' || virsh destroy "$NAME"
	rm -f "$DISK"
	qemu-img create -q -f qcow2 -b "$BASE" -F qcow2 "$DISK"
	cp "$VMDIR/base_VARS.fd" "$(nvram)"
	echo "VM restaurada al estado base."
	;;
*)
	cat <<EOF
Uso: $0 <comando>
  iso       descarga o retoma la descarga de la ISO
  create    crea la VM y arranca desde la ISO
  eject     saca la ISO tras instalar (arranca desde disco)
  console   abre la pantalla en virt-manager
  start     arranca la VM
  stop      apaga la VM
  key       copia la clave SSH dedicada a la VM (VM_USER=$VM_USER)
  ssh [cmd] abre shell o ejecuta comando en la VM
  push      sincroniza el proyecto a ~/archcraft-postinstall en la VM
  run [args] push + ejecuta postinstall.sh en la VM
  base      congela el disco actual como estado limpio
  reset     vuelve la VM al estado limpio
EOF
	;;
esac
