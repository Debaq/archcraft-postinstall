#!/usr/bin/env bash
# Escribe texto en la VM como si fuera teclado y pulsa Enter.
# Útil cuando aún no hay SSH. Uso: [LAYOUT=us|latam] ./vm-type.sh "comando" [--no-enter]
# La ISO live usa teclado us; el sistema instalado, latam.
set -euo pipefail
NAME=archcraft
key() { virsh -c qemu:///session qemu-monitor-command --hmp "$NAME" "sendkey $1" >/dev/null; }
declare -A M=([' ']=spc [-]=minus [_]=shift-minus [.]=dot [/]=slash [=]=equal [+]=shift-equal
	[\;]=semicolon [:]=shift-semicolon [\|]=shift-backslash [\\]=backslash [\&]=shift-7
	[\>]=shift-dot [\<]=shift-comma [,]=comma [\']=apostrophe [\"]=shift-apostrophe
	[\$]=shift-4 [\*]=shift-8 [\(]=shift-9 [\)]=shift-0 [~]=shift-grave_accent [@]=shift-2 [\#]=shift-3)
# Teclas que cambian en latinoamericano
if [[ "${LAYOUT:-latam}" == latam ]]; then
	M+=([-]=slash [_]=shift-slash [/]=shift-7 [=]=shift-0 [\;]=shift-comma [:]=shift-dot
		[\|]=grave_accent [\&]=shift-6 [\>]=shift-less [\<]=less [\']=minus [\"]=shift-2
		[\(]=shift-8 [\)]=shift-9 [@]=altgr-q)
	unset 'M[*]' 'M[~]' 'M[\\]' 'M[+]'
fi
s="$1"
for ((i = 0; i < ${#s}; i++)); do
	c="${s:i:1}"
	if [[ -n "${M[$c]:-}" ]]; then key "${M[$c]}"
	elif [[ "$c" =~ [a-z0-9] ]]; then key "$c"
	elif [[ "$c" =~ [A-Z] ]]; then key "shift-${c,,}"
	else echo "Sin mapeo: '$c'" >&2; exit 1; fi
done
[[ "${2:-}" == "--no-enter" ]] || key ret
