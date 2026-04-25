#!/usr/bin/env bash
# Comandos do menu interativo: add, rm e instalação por estado.
# SECURITY NOTE: Ensure these files are owned by your user and not world-writable.
# Be cautious when adding new modules suggested by LLMs; always review the content.

# Verifica se os comandos necessários estão instalados
dotfiles_menu_check_deps() {
    local dep
    for dep in "$@"; do
        if ! command -v "$dep" >/dev/null 2>&1; then
            echo "Erro: Comando '$dep' não encontrado. Por favor, instale-o." >&2
            return 1
        fi
    done
}

# Remove espaços no início e fim (útil antes de interpretar "add ...").
dotfiles_menu_trim() {
    local s="$1"
    s="${s#"${s%%[![:space:]]*}"}"
    s="${s%"${s##*[![:space:]]}"}"
    printf '%s' "$s"
}

# Confirmação (s/n): aceita s, sim, y, yes — case-insensitive; trim e CR.
dotfiles_menu_is_yes() {
    local a
    a="$(dotfiles_menu_trim "${1:-n}")"
    a="${a,,}"
    a="${a//$'\r'/}"
    case "$a" in
        s|sim|y|yes) return 0 ;;
        *) return 1 ;;
    esac
}

# Parte depois de "add": aceita aspas simples, duplas ou texto solto.
dotfiles_menu_parse_add_name() {
    local rest="$1"
    if [[ "$rest" =~ ^\'(.*)\'$ ]]; then
        printf '%s' "${BASH_REMATCH[1]}"
    elif [[ "$rest" =~ ^\"(.*)\"$ ]]; then
        printf '%s' "${BASH_REMATCH[1]}"
    else
        printf '%s' "$rest"
    fi
}

# Reconhece "add", "add foo" ou "add 'a b'"; confirma e atualiza config/dotfile-names.list + array entries.
dotfiles_menu_try_add() {
    local trimmed=$1
    local -n _add_entries=$2
    local rest name ans

    if [[ "$trimmed" =~ ^[Aa][Dd][Dd]$ ]]; then
        echo ""
        echo "${B}Uso de add${R}"
        printf '  %s\n' "add nome-do-item"
        printf '  %s\n' "add 'nome com espaços'"
        echo ""
        return 0
    fi
    if [[ "$trimmed" =~ ^[Aa][Dd][Dd][[:space:]]+(.+)$ ]]; then
        rest="${BASH_REMATCH[1]}"
        rest="$(dotfiles_menu_trim "$rest")"
        name="$(dotfiles_menu_parse_add_name "$rest")"
        if [[ -z "${name// }" ]]; then
            echo "Erro: nome vazio após add."
            return 0
        fi
        read -r -p "Adicionar \"${name}\" a $(dotfiles_dotfile_names_path)? (sim/não): " ans || true
        if ! dotfiles_menu_is_yes "$ans"; then
            return 0
        fi
        if ! dotfiles_dotfile_names_add_entry "$name"; then
            return 0
        fi
        echo "Adicionado a config/dotfile-names.list: ${name}"
        mapfile -t _add_entries < <(dotfiles_dotfile_names_entries)
        return 0
    fi
    return 1
}

# Reconhece rm1, rm2, … (case-insensitive no prefixo rm); confirma e remove a linha de config/dotfile-names.list.
# Se não sobrar nenhuma entrada, termina o processo com exit 0.
dotfiles_menu_try_rm() {
    local choice="${1//[[:space:]]/}"
    local -n _rm_entries=$2
    local rm_num to_rm ans

    if [[ "${choice,,}" =~ ^rm([0-9]+)$ ]]; then
        rm_num="${BASH_REMATCH[1]}"
        if ((rm_num < 1 || rm_num > ${#_rm_entries[@]})); then
            echo ""
            echo "Número inválido para rm: use 1–${#_rm_entries[@]} (o mesmo intervalo da coluna # na tabela)."
            echo ""
            return 0
        fi
        to_rm="${_rm_entries[$((rm_num - 1))]}"
        read -r -p "Remover \"${to_rm}\" de $(dotfiles_dotfile_names_path)? (sim/não): " ans || true
        if ! dotfiles_menu_is_yes "$ans"; then
            return 0
        fi
        if ! dotfiles_dotfile_names_remove_entry "$to_rm"; then
            return 0
        fi
        echo "Removido de config/dotfile-names.list: ${to_rm}"
        mapfile -t _rm_entries < <(dotfiles_dotfile_names_entries)
        if ((${#_rm_entries[@]} == 0)); then
            echo "Nenhuma entrada restante em $(dotfiles_dotfile_names_path)."
            exit 0
        fi
        return 0
    fi
    return 1
}

dotfiles_menu_commit_file() {
    local file=$1
    local key_file data_dir repo_root api_key diff_output response commit_msg ans
    
    key_file="$(dotfiles_repo_root)/config/.google_ai_studio_api_key"
    data_dir="$(dotfiles_data_dir)"
    repo_root="$(dotfiles_repo_root)"
    
    if [[ ! -f "$key_file" ]]; then
        echo "A API key do Google AI Studio não foi encontrada."
        read -r -p "Deseja adicionar uma agora para gerar mensagens de commit? (sim/não): " ans || true
        if ! dotfiles_menu_is_yes "$ans"; then
            return 0
        fi
        echo -n "Cole sua API key do Google AI Studio (não será exibida): "
        read -rs api_key
        echo ""
        if [[ -z "$api_key" ]]; then
            echo "Nenhuma chave inserida. Cancelando."
            return 0
        fi
        mkdir -p "$(dirname "$key_file")" || { echo "Erro ao criar diretório da API key." >&2; return 1; }
        echo "GOOGLE_AI_KEY=$api_key" > "$key_file"
        echo "GEMINI_MODEL=gemini-3-flash-live" >> "$key_file"
        chmod 600 "$key_file" || { echo "Erro ao definir permissões na API key." >&2; return 1; }
        echo "API key salva em config/.google_ai_studio_api_key"
    fi
    
    local gemini_model=""
    local line key val
    while IFS='=' read -r key val || [[ -n "$key" ]]; do
        # Remove possíveis espaços extras e CR
        key=$(echo "$key" | tr -d '[:space:]')
        val=$(echo "$val" | tr -d '\r')
        case "$key" in
            GOOGLE_AI_KEY) api_key="$val" ;;
            GEMINI_MODEL)  gemini_model="$val" ;;
        esac
    done < "$key_file"

    gemini_model="${gemini_model:-gemini-3-flash-live}"
    
    if ! dotfiles_menu_check_deps jq curl; then
        return 1
    fi

    echo "Gerando mensagem de commit para $file..."
    
    # Obter o diff do arquivo específico
    local rel_path="data/${file}"
    diff_output="$(git -C "$repo_root" diff HEAD -- "$rel_path" 2>/dev/null)"
    
    if [[ -z "$diff_output" ]]; then
        echo "Nenhuma alteração detectada para $file pelo git ou arquivo não rastreado."
        return 0
    fi
    
    local json_payload
    json_payload=$(jq -n --arg diff "$diff_output" '{
      "contents": [{
        "parts": [{
          "text": ("Você é um assistente que escreve mensagens de commit baseadas em diffs de git. Escreva APENAS a mensagem de commit usando o padrão Conventional Commits. Seja conciso. Aqui está o diff:\n\n" + $diff)
        }]
      }]
    }') || { echo "Erro ao preparar JSON para a API." >&2; return 1; }
    
    response=$(curl -s -f -X POST -H "Content-Type: application/json" \
        -d "$json_payload" \
        "https://generativelanguage.googleapis.com/v1beta/models/${gemini_model}:generateContent?key=${api_key}")
    
    if [[ $? -ne 0 ]]; then
        echo "Erro: Falha na requisição à API do Gemini (verifique sua chave e conexão)." >&2
        return 1
    fi
        
    commit_msg=$(echo "$response" | jq -r '.candidates[0].content.parts[0].text // empty' 2>/dev/null)
    
    if [[ -z "$commit_msg" ]]; then
        echo "Erro ao gerar a mensagem de commit. Resposta da API:"
        echo "$response"
        return 0
    fi
    
    # Limpa possíveis blocos de código markdown da resposta
    commit_msg=$(echo "$commit_msg" | sed 's/^```[a-zA-Z]*$//g' | sed 's/^```$//g' | awk 'NF')
    
    echo ""
    echo "======================================"
    echo -e "${B:-}Mensagem sugerida:${R:-}"
    echo "$commit_msg"
    echo "======================================"
    echo ""
    
    read -r -p "Confirmar e realizar o commit deste arquivo? (sim/não): " ans || true
    if ! dotfiles_menu_is_yes "$ans"; then
        echo "Commit cancelado."
        return 0
    fi
    
    git -C "$repo_root" commit -m "$commit_msg" -- "$rel_path"
    echo "Commit realizado com sucesso!"
}

# Reage ao estado devolvido por dotfiles_status_for_file (importar, bloquear, link errado, etc.).
# importable: pode mover ~ → data/ e já criar o link aqui (return 0).
# wrong_target: pergunta; só return 1 se o utilizador quiser substituir (o caller chama dotfiles_link_one).
dotfiles_menu_act_on_entry() {
    local file=$1
    local st dest data_src ans ovr

    st="$(dotfiles_status_for_file "$file")"
    if [[ "$st" == "installed" ]] && dotfiles_file_has_changes "$file"; then
        st="installed_modified"
    fi

    case "$st" in
        installed_modified)
            dotfiles_menu_commit_file "$file"
            return 0
            ;;
        # Arquivo existe em ~ mas não em data/: opção de mover para o repo e linkar.
        importable)
            dest="$(dotfiles_dest_for_file "$file")"
            data_src="$(dotfiles_data_dir)/${file}"
            read -r -p "Não há cópia em data/, mas existe ${dest}. Mover para o repositório e criar o link? (sim/não): " ans || true
            if ! dotfiles_menu_is_yes "$ans"; then
                return 0
            fi
            mkdir -p "$(dirname "$data_src")" || { echo "Erro ao criar diretório em data/." >&2; return 0; }
            mv -- "$dest" "$data_src" || { echo "Erro ao mover arquivo para o repositório." >&2; return 0; }
            echo ""
            dotfiles_link_one "$file"
            echo "Feito."
            return 0
            ;;
        # Sem fonte em data/ e nada importável em ~.
        unavailable)
            echo "Não dá para instalar: crie primeiro ${SCRIPT_DIR}/data/${file}"
            return 0
            ;;
        # Symlink já aponta para este repositório.
        installed)
            echo "Já está instalado corretamente: $file"
            read -r -p "Deseja remover o link simbólico em $(dotfiles_dest_for_file "$file")? (sim/não): " ans || true
            if ! dotfiles_menu_is_yes "$ans"; then
                return 0
            fi
            echo ""
            dotfiles_unlink_one "$file"
            echo "Feito."
            return 0
            ;;
        # Caminho de destino existe mas não é symlink (impede ln -s): backup em .bkp e link.
        blocking_file)
            dest="$(dotfiles_dest_for_file "$file")"
            read -r -p "Há um arquivo/pasta real em ${dest} (não é link). Mover para $(dotfiles_backup_dir)/ e criar o link? (sim/não): " ans || true
            if ! dotfiles_menu_is_yes "$ans"; then
                return 0
            fi
            if ! dotfiles_move_blocking_dest_to_bkp "$file"; then
                return 0
            fi
            echo ""
            dotfiles_link_one "$file"
            echo "Feito."
            return 0
            ;;
        # Symlink existe mas aponta para outro sítio: substituir ou abortar.
        wrong_target)
            read -r -p "Substituir o link por um que aponta para este repositório? (sim/não): " ovr || true
            dotfiles_menu_is_yes "$ovr" || return 0
            return 1
            ;;
        # Falta criar o link; o caller trata com dotfiles_link_one.
        not_installed)
            return 1
            ;;
        *) # Defesa: novo estado em lib.sh sem ramo aqui — não tentar link à cegas.
            echo "Estado inesperado para ${file}: ${st}" >&2
            return 0
            ;;
    esac
}
