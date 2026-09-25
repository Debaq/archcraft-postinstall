#!/usr/bin/env bash
# Post-instalación para Archcraft: aplica los módulos de modules/ en orden.
# Uso: ./postinstall.sh            ejecuta todos los módulos
#      ./postinstall.sh 10 paquetes ejecuta solo los módulos que coincidan
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
export ROOT FILES="$ROOT/files"

[[ $EUID -ne 0 ]] || { echo "Ejecutar como usuario normal (usa sudo cuando hace falta)" >&2; exit 1; }

source "$ROOT/lib.sh"
source "$ROOT/config.sh"

# Pide la contraseña de sudo una vez y la mantiene vigente mientras corre el script.
# SUDO_PASS permite correrlo sin terminal interactiva (pruebas en la VM).
if [[ -n "${SUDO_PASS:-}" ]]; then
	SUDO_ASKPASS="$(mktemp)"
	printf '#!/bin/sh\necho "$SUDO_PASS"\n' >"$SUDO_ASKPASS"
	chmod 700 "$SUDO_ASKPASS"
	export SUDO_PASS SUDO_ASKPASS
	sudo() { command sudo -A "$@"; }
fi
sudo -v
# Renueva el permiso de sudo; si una renovación falla no se corta (set -e se hereda)
if [[ -n "${SUDO_PASS:-}" ]]; then renew=(sudo -v); else renew=(sudo -n -v); fi
while sleep 50; do "${renew[@]}" || true; done 2>/dev/null &
keepalive=$!
trap 'kill $keepalive 2>/dev/null || true; rm -f "${SUDO_ASKPASS:-}"' EXIT

mapfile -t modules < <(ls "$ROOT"/modules/*.sh 2>/dev/null | sort)
for m in "${modules[@]}"; do
	name="$(basename "$m" .sh)"
	if (($#)); then
		match=0
		for f in "$@"; do [[ "$name" == *"$f"* ]] && match=1; done
		((match)) || continue
	fi
	step "$name"
	( source "$m" )
done
ok "Listo"
