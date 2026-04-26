#!/usr/bin/env bash
# Comandos do menu interativo: add, rm, commit e instalação por estado.
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
        printf '  %s\n' "add ~/.ssh/config"
        printf '  %s\n' "add 'nome com espaços'"
        echo ""
        return 0
    fi
    if [[ "$trimmed" =~ ^[Aa][Dd][Dd][[:space:]]+(.+)$ ]]; then
        rest="${BASH_REMATCH[1]}"
        rest="$(dotfiles_menu_trim "$rest")"
        name="$(dotfiles_menu_parse_add_name "$rest")"
        
        # Converte caminhos absolutos ou com ~ para nomes relativos à Home
        if [[ "$name" == "$HOME"* ]]; then
            name="${name#$HOME}"
            name="${name#/}"
        elif [[ "$name" == "~"* ]]; then
            name="${name#~}"
            name="${name#/}"
        fi

        if [[ -z "${name// }" ]]; then
            echo "Erro: nome vazio após processar add."
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

# Carrega a API key do Google AI Studio e configura a lista de modelos de fallback.
# Preenche as variáveis passadas por nameref: _api_key e _models (array).
# Retorna 1 se a key não puder ser obtida.
dotfiles_menu_load_api_key() {
    local -n _api_key_ref=$1
    local -n _models_ref=$2
    local key_file ans gemini_model=""
    key_file="$(dotfiles_repo_root)/config/.google_ai_studio_api_key"

    if [[ ! -f "$key_file" ]]; then
        echo "A API key do Google AI Studio não foi encontrada."
        read -r -p "Deseja adicionar uma agora? (sim/não): " ans || true
        if ! dotfiles_menu_is_yes "$ans"; then
            return 1
        fi
        echo -n "Cole sua API key do Google AI Studio (não será exibida): "
        read -rs _api_key_ref
        echo ""
        if [[ -z "$_api_key_ref" ]]; then
            echo "Nenhuma chave inserida. Cancelando."
            return 1
        fi
        mkdir -p "$(dirname "$key_file")" || { echo "Erro ao criar diretório da API key." >&2; return 1; }
        echo "GOOGLE_AI_KEY=$_api_key_ref" > "$key_file"
        echo "GEMINI_MODEL=gemini-2.0-flash" >> "$key_file"
        chmod 600 "$key_file" || { echo "Erro ao definir permissões na API key." >&2; return 1; }
        echo "API key salva em config/.google_ai_studio_api_key"
    fi

    local line key val
    while IFS='=' read -r key val || [[ -n "$key" ]]; do
        key=$(echo "$key" | tr -d '[:space:]')
        val=$(echo "$val" | tr -d '\r')
        case "$key" in
            GOOGLE_AI_KEY) _api_key_ref="$val" ;;
            GEMINI_MODEL)  gemini_model="$val" ;;
        esac
    done < "$key_file"

    local fallback_models=(
        "${gemini_model:-gemini-3.1-flash-lite-preview}"
        "gemini-3.1-flash-lite-preview"
        "gemini-3-flash-preview"
        "gemini-2.5-flash"
        "gemma-3-27b-it"
        "gemini-2.0-flash"
        "gemini-flash-latest"
    )
    local m
    _models_ref=()
    for m in "${fallback_models[@]}"; do
        [[ " ${_models_ref[*]} " =~ " ${m} " ]] || _models_ref+=("$m")
    done
    return 0
}

# Envia um prompt para a API do Google AI Studio com fallback de modelos.
# Lê o prompt de stdin, retorna a resposta textual via stdout.
# Retorna 1 se todos os modelos falharem.
dotfiles_menu_call_gemini_api() {
    local api_key=$1
    shift
    local -a models=("$@")
    local prompt
    prompt=$(cat)

    local json_payload response current_model api_error result
    json_payload=$(jq -n --arg prompt "$prompt" '{
      "contents": [{
        "parts": [{
          "text": $prompt
        }]
      }]
    }') || { echo "Erro ao preparar JSON." >&2; return 1; }

    for current_model in "${models[@]}"; do
        [[ "$current_model" != "${models[0]}" ]] && echo -e "${C_LINK_STATUS_UNLINKED:-}  ↪ Tentando fallback: ${current_model}...${R:-}" >&2

        response=$(curl -s -X POST -H "Content-Type: application/json" \
            -d "$json_payload" \
            "https://generativelanguage.googleapis.com/v1beta/models/${current_model}:generateContent?key=${api_key}")

        if [[ $? -ne 0 ]]; then
            continue
        fi

        api_error=$(echo "$response" | jq -r '.error.message // empty' 2>/dev/null)
        if [[ -n "$api_error" ]]; then
            [[ "${api_error,,}" == *"quota"* || "${api_error,,}" == *"limit"* || "${api_error,,}" == *"high demand"* || "${api_error,,}" == *"overloaded"* || "${api_error,,}" == *"temporarily"* ]] && continue
            echo -e "${C_MARK_BLOCK:-}✖ Erro na API (${current_model}): $api_error${R:-}" >&2
            break
        fi

        result=$(echo "$response" | jq -r '.candidates[0].content.parts[0].text // empty' 2>/dev/null)
        if [[ -n "$result" ]]; then
            echo "$result"
            return 0
        fi
    done
    return 1
}

# Valida o script bash gerado pela LLM usando uma Allowlist estrita.
# Retorna 0 se o script for seguro, ou 1 se contiver comandos não autorizados.
dotfiles_menu_validate_llm_script() {
    local script_content="$1"
    local line trimmed
    
    while IFS= read -r line || [[ -n "$line" ]]; do
        # Remove espaços nas pontas
        trimmed=$(echo "$line" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
        
        # Permite linhas vazias e comentários (incluindo shebang)
        if [[ -z "$trimmed" || "$trimmed" == "#"* ]]; then
            continue
        fi
        
        # Permite apenas os seguintes comandos:
        if [[ "$trimmed" == "set "* ]] || \
           [[ "$trimmed" == "git add "* ]] || \
           [[ "$trimmed" == "git commit "* ]]; then
            continue
        fi
        
        # Qualquer outra coisa é rejeitada
        echo "$trimmed"
        return 1
    done <<< "$script_content"
    
    return 0
}

# Reconhece o comando "commit" no menu principal.
# Retorna 0 se reconheceu (tratado ou cancelado); 1 se não reconheceu.
dotfiles_menu_try_smart_commit() {
    local trimmed=$1
    if [[ "${trimmed,,}" == "commit" ]]; then
        dotfiles_menu_smart_commit
        return 0
    fi
    return 1
}

# Smart Commit: coleta o diff completo do repo, envia para a LLM,
# e recebe de volta um script bash com múltiplos commits agrupados inteligentemente.
dotfiles_menu_smart_commit() {
    local repo_root api_key ans
    local -a models
    repo_root="$(dotfiles_repo_root)"

    if ! dotfiles_menu_check_deps jq curl; then
        return 0
    fi

    # Verifica se há alterações
    local status_output
    status_output=$(git -C "$repo_root" status --porcelain 2>/dev/null)
    if [[ -z "$status_output" ]]; then
        echo -e "${C_MARK_NONE:-}⚠ Nenhuma alteração detectada no repositório.${R:-}"
        return 0
    fi

    # Carrega API key
    if ! dotfiles_menu_load_api_key api_key models; then
        return 0
    fi

    echo -e "${B:-}✨ Analisando alterações do repositório para smart commit...${R:-}"
    echo ""

    # Coleta diff de tracked files + lista de untracked
    local diff_output untracked_files full_context
    diff_output=$(git -C "$repo_root" diff HEAD 2>/dev/null || true)
    untracked_files=$(git -C "$repo_root" ls-files --others --exclude-standard 2>/dev/null || true)

    # Para arquivos novos (untracked), mostra o conteúdo para a LLM ter contexto
    local untracked_content=""
    if [[ -n "$untracked_files" ]]; then
        local f fsize
        while IFS= read -r f; do
            [[ -z "$f" ]] && continue
            fsize=$(wc -c < "$repo_root/$f" 2>/dev/null || echo "0")
            if (( fsize < 50000 )); then
                untracked_content+=$'\n--- NEW FILE: '"$f"$' ---\n'
                untracked_content+=$(cat "$repo_root/$f" 2>/dev/null || true)
                untracked_content+=$'\n--- END FILE ---\n'
            else
                untracked_content+=$'\n--- NEW FILE: '"$f"$' (too large, '"${fsize}"$' bytes) ---\n'
            fi
        done <<< "$untracked_files"
    fi

    full_context="GIT STATUS:\n${status_output}"
    [[ -n "$diff_output" ]] && full_context+="\n\nDIFF:\n${diff_output}"
    [[ -n "$untracked_content" ]] && full_context+="\n\nNEW FILES:\n${untracked_content}"

    # Check tamanho total
    local context_size=${#full_context}
    if (( context_size > 200000 )); then
        echo -e "${C_MARK_BLOCK:-}✖ Contexto muito grande (${context_size} bytes). Faça commits menores.${R:-}"
        return 0
    fi

    echo -e "${C_FILE_PATH:-}📊 Status: $(echo "$status_output" | wc -l) arquivo(s) alterado(s)${R:-}"
    echo ""

    # Prompt engenheirado para a LLM retornar um script bash
    local prompt
    read -r -d '' prompt << 'PROMPT_HEREDOC' || true
Você é um especialista em Git com Conventional Commits. Analise as alterações abaixo e gere um script bash que faça commits inteligentes.

REGRAS OBRIGATÓRIAS:
1. Agrupe alterações logicamente relacionadas no mesmo commit (ex: mesmo feature, mesmo refactor).
2. Use Conventional Commits: <type>(<scope>): <description>
3. Cada commit deve representar UMA mudança lógica coesa.
4. Use git add para cada arquivo ANTES do git commit.
5. Para arquivos novos (untracked), use git add <arquivo> antes do commit.
6. NUNCA use git add . ou git add -A — sempre adicione arquivos específicos.
7. Mensagens de commit em inglês, imperativo, <72 chars.
8. O script deve ser executável e seguro (sem force push, sem reset).
9. Se um único commit é suficiente para todas as alterações, faça apenas um.
10. NUNCA crie um commit isolado apenas para mudanças triviais (ex: adicionar uma linha em branco, trailing newline, formatação menor). Junte essas mudanças triviais no commit principal mais próximo ou agrupe-as de forma inteligente.

FORMATO DE SAÍDA — responda APENAS com o bloco de código bash, sem explicações:
```bash
#!/usr/bin/env bash
set -euo pipefail

# Commit 1: <breve explicação>
git add <arquivos>
git commit -m "<type>(<scope>): <description>"

# Commit 2: <breve explicação>
git add <arquivos>
git commit -m "<type>(<scope>): <description>"
```

ALTERAÇÕES:
PROMPT_HEREDOC

    prompt+=$'\n'
    prompt+=$(echo -e "$full_context")

    echo -e "${B:-}🤖 Enviando para a LLM...${R:-}"

    local llm_response
    llm_response=$(echo "$prompt" | dotfiles_menu_call_gemini_api "$api_key" "${models[@]}")

    if [[ -z "$llm_response" ]]; then
        echo -e "${C_MARK_BLOCK:-}✖ Não foi possível gerar o script de commits (todos os modelos falharam).${R:-}"
        return 0
    fi

    # Extrai apenas o bloco bash do response (remove markdown fences)
    local script_content
    script_content=$(echo "$llm_response" | sed -n '/^```bash/,/^```$/p' | sed '1d;$d')

    # Fallback: tenta qualquer bloco de código
    if [[ -z "$script_content" ]]; then
        script_content=$(echo "$llm_response" | sed -n '/^```/,/^```$/p' | sed '1d;$d')
    fi
    # Último fallback: usa a resposta inteira
    if [[ -z "$script_content" ]]; then
        script_content="$llm_response"
    fi

    # Validação de segurança baseada em Allowlist (Strict)
    local invalid_cmd
    invalid_cmd=$(dotfiles_menu_validate_llm_script "$script_content")
    if [[ $? -ne 0 ]]; then
        echo -e "${C_MARK_BLOCK:-}✖ SEGURANÇA: O script contém comandos não permitidos pela allowlist. Abortando.${R:-}"
        echo -e "${C_FILE_PATH:-}Comando rejeitado: ${invalid_cmd}${R:-}"
        echo ""
        echo -e "${C_FILE_PATH:-}Script completo recebido:${R:-}"
        echo "$script_content"
        return 0
    fi

    # Exibe o script para revisão
    echo ""
    echo -e "${B:-}╭─────────────────────────────────────────────────────────────────╮${R:-}"
    echo -e "${B:-}│ 📝 Script de Commits Inteligentes                              │${R:-}"
    echo -e "${B:-}╰─────────────────────────────────────────────────────────────────╯${R:-}"
    echo ""
    echo "$script_content" | cat -n
    echo ""
    echo -e "${B:-}╭─────────────────────────────────────────────────────────────────╮${R:-}"
    echo -e "${B:-}│ ⚠  Revise o script acima com atenção antes de confirmar.        │${R:-}"
    echo -e "${B:-}╰─────────────────────────────────────────────────────────────────╯${R:-}"
    echo ""

    local commit_count
    commit_count=$(echo "$script_content" | grep -c '^git commit' || true)
    echo -e "${C_MARK_INST:-}📦 ${commit_count} commit(s) serão criados.${R:-}"
    echo ""

    read -r -p "Executar este script de commits? (sim/não): " ans || true
    if ! dotfiles_menu_is_yes "$ans"; then
        echo "Smart commit cancelado."
        return 0
    fi

    echo ""
    echo -e "${B:-}🚀 Executando commits...${R:-}"
    echo ""

    # Executa o script no diretório do repo em subshell
    ( cd "$repo_root" && eval "$script_content" )
    local exit_code=$?

    if [[ $exit_code -eq 0 ]]; then
        echo ""
        echo -e "${C_MARK_INST:-}✅ Smart commit concluído com sucesso!${R:-}"
        
        # Opção de push após commit
        echo ""
        read -r -p "Deseja fazer o 'git push' agora? (sim/não): " ans || true
        if dotfiles_menu_is_yes "$ans"; then
            echo -e "${B:-}🚀 Enviando para o repositório remoto...${R:-}"
            git -C "$repo_root" push
            if [[ $? -eq 0 ]]; then
                echo -e "${C_MARK_INST:-}✅ Push concluído!${R:-}"
            else
                echo -e "${C_MARK_BLOCK:-}✖ Erro no push. Verifique o seu terminal/git.${R:-}"
            fi
        fi
    else
        echo ""
        echo -e "${C_MARK_BLOCK:-}✖ Erro durante a execução (exit code: ${exit_code}).${R:-}"
        echo -e "${C_FILE_PATH:-}Verifique o estado do repo com 'git status' e 'git log'.${R:-}"
    fi
}

dotfiles_menu_commit_file() {
    local file=$1
    local key_file data_dir repo_root api_key diff_output response commit_msg ans
    
    echo ""
    echo "Opções de commit AI para ${file}:"
    echo "  1) Usar API Nativa (Google AI Studio via Curl)"
    echo "  2) Usar Gemini CLI (gera mensagem, bash commita)"
    echo "  3) Cancelar"
    read -r -p "Escolha uma opção [1-3] (padrão 1): " commit_opt || true
    
    if [[ "$commit_opt" == "2" ]]; then
        # Tenta carregar o NVM caso o gemini não esteja no PATH atual
        if ! command -v gemini >/dev/null 2>&1; then
            export NVM_DIR="$HOME/.nvm"
            [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
        fi

        if ! command -v gemini >/dev/null 2>&1; then
            echo -e "${C_MARK_BLOCK:-}✖ Erro: comando 'gemini' não encontrado no PATH nem via NVM.${R:-}"
            return 0
        fi

        local repo_root
        repo_root="$(dotfiles_repo_root)"
        local rel_path="data/${file}"

        # O modo headless (-p) do Gemini CLI BLOQUEIA a tool run_shell_command.
        # Por isso, usamos o modo híbrido: Gemini gera a mensagem, bash commita.
        echo -e "${B:-}✨ Gerando mensagem de commit via Gemini CLI para ${file}...${R:-}"

        local diff_for_gemini
        diff_for_gemini="$(git -C "$repo_root" diff HEAD -- "$rel_path" 2>/dev/null)"

        if [[ -z "$diff_for_gemini" ]]; then
            echo -e "${C_MARK_NONE:-}⚠ Nenhuma alteração detectada para $file.${R:-}"
            return 0
        fi

        local gemini_msg
        gemini_msg=$(GEMINI_CLI_TRUST_WORKSPACE=true gemini -p \
            "Analise este diff git e gere APENAS uma mensagem de commit usando o padrão Conventional Commits. Responda SOMENTE com a mensagem de commit, sem explicações, sem blocos de código, sem prefixos como 'Resposta:'. Apenas a mensagem pura.

${diff_for_gemini}" 2>/dev/null)

        if [[ -z "$gemini_msg" ]]; then
            echo -e "${C_MARK_BLOCK:-}✖ Não foi possível gerar a mensagem de commit via Gemini CLI.${R:-}"
            return 0
        fi

        # Limpa possíveis blocos de código markdown da resposta
        gemini_msg=$(echo "$gemini_msg" | sed 's/^```[a-zA-Z]*$//g' | sed 's/^```$//g' | awk 'NF')

        echo ""
        echo -e "${B:-}╭─────────────────────────────────────────────────────────────────╮${R:-}"
        echo -e "${B:-}│ Sugestão de Commit (Gemini CLI):${R:-}"
        echo -e "${B:-}│${R:-} $gemini_msg"
        echo -e "${B:-}╰─────────────────────────────────────────────────────────────────╯${R:-}"
        echo ""

        read -r -p "Confirmar e realizar o commit deste arquivo? (sim/não): " ans || true
        if ! dotfiles_menu_is_yes "$ans"; then
            echo "Commit cancelado."
            return 0
        fi

        git -C "$repo_root" add -- "$rel_path"
        git -C "$repo_root" commit -m "$gemini_msg" -- "$rel_path"
        echo "Commit realizado com sucesso!"
        
        echo ""
        read -r -p "Deseja fazer o 'git push' agora? (sim/não): " ans || true
        if dotfiles_menu_is_yes "$ans"; then
            echo -e "${B:-}🚀 Enviando para o repositório remoto...${R:-}"
            git -C "$repo_root" push
        fi
        
        return 0
    elif [[ -n "$commit_opt" && "$commit_opt" != "1" ]]; then
        echo "Commit cancelado."
        return 0
    fi

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
        echo "GEMINI_MODEL=gemini-2.0-flash" >> "$key_file"
        chmod 600 "$key_file" || { echo "Erro ao definir permissões na API key." >&2; return 1; }
        echo "API key salva em config/.google_ai_studio_api_key"
        echo "Dica: Você pode configurar fallbacks editando este arquivo."
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

    # Lista de modelos gratuitos ordenados por limite/eficiência (RPM: 15 para Flash, 2 para Pro)
    local fallback_models=(
        "${gemini_model:-gemini-3.1-flash-lite-preview}"
        "gemini-3.1-flash-lite-preview"
        "gemini-3-flash-preview"
        "gemini-2.5-flash"
        "gemma-3-27b-it"
        "gemini-2.0-flash"
        "gemini-flash-latest"
    )

    # Remove duplicatas da lista mantendo a ordem
    local models=()
    local m
    for m in "${fallback_models[@]}"; do
        [[ " ${models[*]} " =~ " ${m} " ]] || models+=("$m")
    done

    if ! dotfiles_menu_check_deps jq curl; then
        return 1
    fi

    echo -e "${B:-}✨ Gerando mensagem de commit para ${file}...${R:-}"
    
    # Obter o diff do arquivo específico
    local rel_path="data/${file}"
    diff_output="$(git -C "$repo_root" diff HEAD -- "$rel_path" 2>/dev/null)"
    
    if [[ -z "$diff_output" ]]; then
        echo -e "${C_MARK_NONE:-}⚠ Nenhuma alteração detectada para $file pelo git ou arquivo não rastreado.${R:-}"
        return 0
    fi

    # Check for diff size (e.g., > 100KB)
    local diff_size=${#diff_output}
    if (( diff_size > 100000 )); then
        echo -e "${C_MARK_BLOCK:-}✖ Diff muito grande (${diff_size} bytes).${R:-}" >&2
        return 0
    fi
    
    local json_payload
    json_payload=$(jq -n --arg diff "$diff_output" '{
      "contents": [{
        "parts": [{
          "text": ("Você é um assistente que escreve mensagens de commit baseadas em diffs de git. Escreva APENAS a mensagem de commit usando o padrão Conventional Commits. Seja conciso. Aqui está o diff:\n\n" + $diff)
        }]
      }]
    }') || { echo -e "${C_MARK_BLOCK:-}✖ Erro ao preparar JSON.${R:-}" >&2; return 1; }
    
    commit_msg=""
    local current_model
    for current_model in "${models[@]}"; do
        [[ "$current_model" != "${models[0]}" ]] && echo -e "${C_LINK_STATUS_UNLINKED:-}  ↪ Tentando fallback: ${current_model}...${R:-}"

        response=$(curl -s -X POST -H "Content-Type: application/json" \
            -d "$json_payload" \
            "https://generativelanguage.googleapis.com/v1beta/models/${current_model}:generateContent?key=${api_key}")
        
        if [[ $? -ne 0 ]]; then
            continue # Erro de rede, tenta o próximo
        fi
            
        local api_error
        api_error=$(echo "$response" | jq -r '.error.message // empty' 2>/dev/null)
        
        if [[ -n "$api_error" ]]; then
            # Se for erro de quota (429), apenas continua para o próximo modelo silenciosamente
            [[ "$api_error" == *"quota"* || "$api_error" == *"limit"* ]] && continue
            
            # Outros erros (chave inválida, etc) a gente avisa e para o loop de modelos
            echo -e "${C_MARK_BLOCK:-}✖ Erro na API (${current_model}): $api_error${R:-}" >&2
            break
        fi

        commit_msg=$(echo "$response" | jq -r '.candidates[0].content.parts[0].text // empty' 2>/dev/null)
        [[ -n "$commit_msg" ]] && break
    done
    
    if [[ -z "$commit_msg" ]]; then
        echo -e "${C_MARK_BLOCK:-}✖ Não foi possível gerar a mensagem de commit (todos os modelos falharam).${R:-}" >&2
        return 0
    fi
    
    # Limpa possíveis blocos de código markdown da resposta
    commit_msg=$(echo "$commit_msg" | sed 's/^```[a-zA-Z]*$//g' | sed 's/^```$//g' | awk 'NF')
    
    echo ""
    echo -e "${B:-}╭─────────────────────────────────────────────────────────────────╮${R:-}"
    echo -e "${B:-}│ Sugestão de Commit (${current_model}):${R:-}"
    echo -e "${B:-}│${R:-} $commit_msg"
    echo -e "${B:-}╰─────────────────────────────────────────────────────────────────╯${R:-}"
    echo ""
    
    read -r -p "Confirmar e realizar o commit deste arquivo? (sim/não): " ans || true
    if ! dotfiles_menu_is_yes "$ans"; then
        echo "Commit cancelado."
        return 0
    fi
    
    git -C "$repo_root" commit -m "$commit_msg" -- "$rel_path"
    echo "Commit realizado com sucesso!"
    
    echo ""
    read -r -p "Deseja fazer o 'git push' agora? (sim/não): " ans || true
    if dotfiles_menu_is_yes "$ans"; then
        echo -e "${B:-}🚀 Enviando para o repositório remoto...${R:-}"
        git -C "$repo_root" push
    fi
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
