# Funciones comunes para los módulos.

step() { printf '\n\e[1;34m==> %s\e[0m\n' "$*"; }
ok()   { printf '\e[1;32m  ✓ %s\e[0m\n' "$*"; }
warn() { printf '\e[1;33m  ! %s\e[0m\n' "$*" >&2; }

# Instala solo los paquetes que falten (pacman -T lista los ausentes)
pkg_install() {
	local missing
	mapfile -t missing < <(pacman -T "$@")
	((${#missing[@]})) || return 0
	sudo pacman -S --needed --noconfirm "${missing[@]}" >/dev/null && ok "Instalados: ${missing[*]}"
}

# Desinstala paquetes instalados. Salta (con aviso) los que necesita un paquete que se queda;
# si quien lo necesita también está en la lista, se quitan juntos.
pkg_remove() {
	local p r skip changed=1
	local -A set=() req=()
	for p in "$@"; do pacman -Qq "$p" &>/dev/null && set[$p]=1; done
	for p in "${!set[@]}"; do req[$p]="$(LC_ALL=C pacman -Qi "$p" | sed -n 's/^Required By *: //p')"; done
	while ((changed)); do
		changed=0
		for p in "${!set[@]}"; do
			skip=""
			for r in ${req[$p]}; do [[ "$r" == None || -n "${set[$r]:-}" ]] || skip="$r"; done
			[[ -z "$skip" ]] && continue
			warn "$p no se quita: lo necesita $skip"
			unset "set[$p]"
			changed=1
		done
	done
	((${#set[@]})) || return 0
	sudo pacman -Rns --noconfirm "${!set[@]}" >/dev/null && ok "Quitados ${#set[@]} paquetes"
}

# Copia un archivo de files/ a destino, respaldando el original una vez
put_file() {
	local src="$FILES/$1" dst="$2"
	mkdir -p "$(dirname "$dst")"
	[[ -e "$dst" && ! -e "$dst.orig" ]] && cp -a "$dst" "$dst.orig"
	cp -a "$src" "$dst"
}

# Activa/desactiva units solo si existen
unit_exists() { systemctl list-unit-files "$1" &>/dev/null && [[ -n "$(systemctl list-unit-files --no-legend "$1")" ]]; }

# Escribe contenido (stdin) en archivo del sistema solo si cambió. Devuelve 0 si cambió.
sys_write() {
	local dst="$1" tmp
	tmp="$(mktemp)"
	cat >"$tmp"
	if sudo cmp -s "$tmp" "$dst" 2>/dev/null; then rm -f "$tmp"; return 1; fi
	sudo install -Dm644 "$tmp" "$dst"
	rm -f "$tmp"
}

# URL del asset en la release más nueva cuyo tag empiece con el prefijo
gh_asset_url() {
	local repo="$1" prefix="$2" asset="$3"
	curl -fsSL "https://api.github.com/repos/$repo/releases?per_page=30" |
		jq -r --arg p "$prefix" --arg a "$asset" \
			'[.[] | select(.tag_name | startswith($p)) | .assets[] | select(.name == $a)][0].browser_download_url // empty'
}
