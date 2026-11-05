# Alerta de terminal do Chunk Injector (lê o cache atualizado pelo timer a cada 5 min).
# Se o cache ainda não existir na sessão, não bloqueia o startup do shell.
_dotfiles_chunk_injector_banner() {
    [[ -o interactive ]] || return 0
    local alert_file="${XDG_CACHE_HOME:-$HOME/.cache}/dotfiles/chunk-injector-alert.txt"
    [[ -s "$alert_file" ]] || return 0

    local line id status target selector desc count=0
    printf '\033[1;33m⚠️  [chunk-injector] Trecho(s) de configuração ausente(s) ou alterado(s):\033[0m\n' >&2
    while IFS='|' read -r id status target selector desc; do
        [[ -z "$id" || "$id" == \#* ]] && continue
        count=$((count + 1))
        printf '   \033[0;31m• %s\033[0m (%s): \033[1m%s\033[0m [%s] — %s\n' \
            "$id" "$status" "$target" "$selector" "$desc" >&2
    done <"$alert_file"

    if ((count > 0)); then
        printf '   \033[0;36m→ Rode \033[1mchunk-injector inject\033[0;36m (ou \033[1mchunks\033[0;36m no dotfiles-menu) para restaurar.\033[0m\n\n' >&2
    fi
}

_dotfiles_chunk_injector_banner
unfunction _dotfiles_chunk_injector_banner 2>/dev/null || true
