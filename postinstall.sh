#!/usr/bin/env bash
# Post-instalación para Archcraft: aplica los módulos de modules/ en orden.
# Uso: ./postinstall.sh             aplica los módulos que cambiaron o nunca se aplicaron
#      ./postinstall.sh --todo      aplica todos, aunque ya estén hechos
#      ./postinstall.sh 10 paquetes aplica solo los módulos que coincidan (siempre)
# Antes de empezar se actualiza desde git. Si un módulo falla, sigue con el resto.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
export ROOT FILES="$ROOT/files"

[[ $EUID -ne 0 ]] || { echo "Ejecutar como usuario normal (usa sudo cuando hace falta)" >&2; exit 1; }

source "$ROOT/lib.sh"

# Actualización: si llega una versión nueva, se relanza con ella (una sola vez)
if [[ -z "${POSTINSTALL_ACTUALIZADO:-}" && -d "$ROOT/.git" ]] && command -v git &>/dev/null; then
	step "Actualización"
	antes="$(git -C "$ROOT" rev-parse HEAD)"
	if GIT_TERMINAL_PROMPT=0 timeout 30 git -C "$ROOT" pull --ff-only -q &>/dev/null; then
		if [[ "$(git -C "$ROOT" rev-parse HEAD)" != "$antes" ]]; then
			ok "Actualizado a $(git -C "$ROOT" log --oneline -1)"
			POSTINSTALL_ACTUALIZADO=1 exec "$ROOT/postinstall.sh" "$@"
		fi
		ok "Al día ($(git -C "$ROOT" log --oneline -1))"
	else
		warn "No se pudo actualizar (sin red o con cambios locales): sigue con esta versión"
	fi
fi

source "$ROOT/config.sh"

todo=0 filtros=()
for a in "$@"; do
	if [[ "$a" == --todo ]]; then todo=1; else filtros+=("$a"); fi
done

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

# Módulos ya aplicados: huella del módulo y de todo lo que usa. Si nada cambió, se salta.
ESTADO="${XDG_STATE_HOME:-$HOME/.local/state}/archcraft-postinstall"
mkdir -p "$ESTADO"
comun="$(cat "$ROOT"/{lib.sh,config.sh,diag-audio.sh} $(find "$FILES" -type f | sort) | sha256sum)"
huella() { { cat "$1"; echo "$comun"; } | sha256sum | cut -d' ' -f1; }

aplicados=() sin_cambios=() fallidos=()
mapfile -t modules < <(ls "$ROOT"/modules/*.sh 2>/dev/null | sort)
for m in "${modules[@]}"; do
	name="$(basename "$m" .sh)"
	if ((${#filtros[@]})); then
		match=0
		for f in "${filtros[@]}"; do [[ "$name" == *"$f"* ]] && match=1; done
		((match)) || continue
	elif ((!todo)) && [[ "$(cat "$ESTADO/$name" 2>/dev/null)" == "$(huella "$m")" ]]; then
		sin_cambios+=("$name")
		continue
	fi
	step "$name"
	# set -e dentro del módulo: se corta en el primer error, pero no corta los demás
	set +e
	(
		set -e
		source "$m"
	)
	rc=$?
	set -e
	if ((rc == 0)); then
		huella "$m" >"$ESTADO/$name"
		aplicados+=("$name")
	else
		warn "$name falló (código $rc): se reintenta en la próxima corrida"
		rm -f "$ESTADO/$name"
		fallidos+=("$name")
	fi
done

step "Resumen"
((${#aplicados[@]})) && ok "Aplicados: ${aplicados[*]}"
((${#sin_cambios[@]})) && ok "Ya hechos, sin cambios: ${sin_cambios[*]} (--todo para repetirlos)"
if ((${#fallidos[@]})); then
	warn "Fallaron: ${fallidos[*]}"
	exit 1
fi
ok "Listo"
