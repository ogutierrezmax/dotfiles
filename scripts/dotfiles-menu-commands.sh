#!/usr/bin/env bash
# Comandos do menu interativo: add, rm, commit e instalação por estado.
# SECURITY NOTE: Ensure these files are owned by your user and not world-writable.
# Be cautious when adding new modules suggested by LLMs; always review the content.

# Logging — um arquivo por sessão de commit
# Path: logs/commit-session-YYYY-MM-DD-HHMMSS.log
dotfiles_menu_log_init() {
    local repo_root
    repo_root="$(dotfiles_repo_root)"
    mkdir -p "$repo_root/logs"
    export DOTFILES_COMMIT_LOG="$repo_root/logs/commit-session-$(date '+%Y-%m-%d-%H%M%S').log"
}

dotfiles_menu_log() {
    if [[ -n "${DOTFILES_COMMIT_LOG:-}" ]]; then
        echo "[$(date '+%H:%M:%S')] $*" >> "$DOTFILES_COMMIT_LOG"
    fi
}

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

        # Evita erro de limite de tamanho de argumento (ARG_MAX) passando o JSON via stdin
        response=$(echo "$json_payload" | curl -s -X POST -H "Content-Type: application/json" \
            -d @- \
            "https://generativelanguage.googleapis.com/v1beta/models/${current_model}:generateContent?key=${api_key}")

        if [[ $? -ne 0 ]]; then
            continue
        fi

        api_error=$(echo "$response" | jq -r '.error.message // empty' 2>/dev/null)
        if [[ -n "$api_error" ]]; then
            # Se a chave for expressamente inválida, paramos. Caso contrário (quota, modelo inexistente, etc), tentamos o próximo fallback.
            if [[ "${api_error,,}" == *"api key"* || "${api_error,,}" == *"api_key"* ]]; then
                echo -e "${C_MARK_BLOCK:-}✖ Erro de Autenticação na API: $api_error${R:-}" >&2
                break
            fi
            # Loga o erro em debug/stderr e continua tentando os fallbacks
            [[ "${api_error,,}" == *"quota"* || "${api_error,,}" == *"limit"* || "${api_error,,}" == *"high demand"* || "${api_error,,}" == *"overloaded"* || "${api_error,,}" == *"temporarily"* ]] || \
                echo -e "${C_MARK_BLOCK:-}⚠ Aviso na API (${current_model}): $api_error (tentando fallback)...${R:-}" >&2
            continue
        fi

        result=$(echo "$response" | jq -r '.candidates[0].content.parts[0].text // empty' 2>/dev/null)
        if [[ -n "$result" ]]; then
            echo "$result"
            return 0
        fi
    done
    return 1
}

# Coleta git status + diff + conteúdo de untracked para contexto da LLM.
# Retorna o contexto completo via stdout.
dotfiles_menu_collect_diff() {
    local repo_root="$1"
    local status_output diff_output untracked_files untracked_content="" full_context

    status_output=$(git -C "$repo_root" status --porcelain 2>/dev/null)
    diff_output=$(git -C "$repo_root" diff HEAD 2>/dev/null || true)
    untracked_files=$(git -C "$repo_root" ls-files --others --exclude-standard 2>/dev/null || true)

    dotfiles_menu_log "[COLLECT] status_files=$(echo "$status_output" | wc -l)"
    dotfiles_menu_log "[COLLECT] status_raw: $(echo "$status_output" | tr '\n' ' | ')"

    local diff_size=${#diff_output}
    dotfiles_menu_log "[COLLECT] diff_size=${diff_size} bytes"

    local untracked_count=0
    local untracked_list=""
    if [[ -n "$untracked_files" ]]; then
        local f fsize
        while IFS= read -r f; do
            [[ -z "$f" ]] && continue
            (( untracked_count++ ))
            fsize=$(wc -c < "$repo_root/$f" 2>/dev/null || echo "0")
            untracked_list+="${f}(${fsize}b) "
            if (( fsize < 50000 )); then
                untracked_content+=$'\n--- NEW FILE: '"$f"$' ---\n'
                untracked_content+=$(cat "$repo_root/$f" 2>/dev/null || true)
                untracked_content+=$'\n--- END FILE ---\n'
            else
                untracked_content+=$'\n--- NEW FILE: '"$f"$' (too large, '"${fsize}"$' bytes) ---\n'
            fi
        done <<< "$untracked_files"
    fi

    dotfiles_menu_log "[COLLECT] untracked_count=${untracked_count}, files=[${untracked_list}]"

    full_context="GIT STATUS:\n${status_output}"
    [[ -n "$diff_output" ]] && full_context+="\n\nDIFF:\n${diff_output}"
    [[ -n "$untracked_content" ]] && full_context+="\n\nNEW FILES:\n${untracked_content}"

    local context_size=${#full_context}
    dotfiles_menu_log "[COLLECT] total_context_size=${context_size} bytes"

    echo -e "$full_context"
}

# Envia o diff para a LLM com o prompt adaptado da skill dotfiles-secure-commit.
# Auditoria + agrupamentos + mensagens em 1 chamada.
# Retorna JSON via stdout: { "audit": { "status": "pass|fail|warn", "findings": [...] }, "groups": [...] }
dotfiles_menu_call_llm_audit() {
    local api_key="$1"
    shift
    local full_context="${@: -1}"
    local -a models=("${@:1:$#-1}")
    local context_size=${#full_context}

    if (( context_size > 200000 )); then
        dotfiles_menu_log "[LLM-REQUEST] context_size=${context_size} exceeds 200000 limit, aborting"
        echo -e "${C_MARK_BLOCK:-}✖ Contexto muito grande (${context_size} bytes). Faça commits menores.${R:-}" >&2
        return 1
    fi

    local prompt
    read -r -d '' prompt << 'PROMPT_EOF' || true
Você é um auditor de segurança e especialista em Conventional Commits para repositórios de dotfiles.

SUA FUNÇÃO: Analisar as alterações abaixo e retornar APENAS um objeto JSON.
NÃO execute comandos. NÃO gere scripts bash. NÃO sugira comandos git.
Retorne APENAS JSON válido, sem markdown fences, sem texto adicional.

REGRA CRÍTICA: Use APENAS os caminhos exatos que aparecem no GIT STATUS e DIFF.
NUNCA invente, deduza ou alucine nomes de arquivo.
Se um arquivo aparece como "M scripts/dotfiles-menu-commands.sh", o path é exatamente "scripts/dotfiles-menu-commands.sh".
Se um arquivo aparece como "?? .devtool/features/backlog/file.md", o path é exatamente ".devtool/features/backlog/file.md".
NUNCA use nomes de modelos Gemini como nomes de arquivo.

TAREFA 1 — AUDITORIA DE SEGURANÇA
Analise cada alteração por estas categorias:
- 🔴 BLOQUEAR (status="fail"): segredos/credenciais (api_key, token, secret, password, -----BEGIN, GITHUB_TOKEN, AWS_SECRET, PRIVATE_KEY), chaves privadas (.pem, .key)
- 🟡 ALERTAR (status="warn"): paths absolutos hardcoded (/home/username/, /Users/), permissões excessivas (chmod 777, chmod 666)
- 🟢 INFO (status="pass"): arquivos de backup staged (*.bak*, *.bkp, *~)

Se encontrar qualquer 🔴, status="fail" e liste em findings.
Se encontrar apenas 🟡, status="warn" e liste em findings.
Se nada suspeito, status="pass" e findings=[].

TAREFA 2 — AGRUPAMENTOS E MENSAGENS (só se auditoria NÃO for fail)
Se status != "fail", agrupe arquivos por programa/ferramenta.
Cada grupo = um commit atômico. Use Conventional Commits.
Tipos válidos: feat, fix, docs, chore, security, refactor.
Escopo: nome do programa (ex: vscode, zsh, git, tmux).
Mensagens em inglês, imperativo, <72 chars.

FORMATO JSON EXATO:
{
  "audit": {
    "status": "pass|fail|warn",
    "findings": [
      {"level": "🔴|🟡|🟢", "file": "caminho/do/arquivo", "line": 12, "reason": "descrição"}
    ]
  },
  "groups": [
    {
      "type": "chore",
      "scope": "vscode",
      "description": "add file exclusions",
      "files": [".vscode/settings.json", ".vscode/extensions.json"]
    }
  ]
}

Regras de agrupamento:
- NUNCA misture programas diferentes no mesmo grupo
- NUNCA misture documentação com código/configuração
- NUNCA misture refatoração com novas funcionalidades
- Arquivos de um mesmo programa podem ir juntos se formarem uma mudança lógica
- Ignore mudanças triviais isoladas (espaços em branco)

ALTERAÇÕES:
PROMPT_EOF

    prompt+=$'\n'
    prompt+="$full_context"

    local prompt_size=${#prompt}
    local primary_model="${models[0]}"
    dotfiles_menu_log "[LLM-REQUEST] prompt_size=${prompt_size}, model=${primary_model}, fallbacks=${#models[@]}"

    local llm_response
    llm_response=$(echo "$prompt" | dotfiles_menu_call_gemini_api "$api_key" "${models[@]}")

    if [[ -z "$llm_response" ]]; then
        dotfiles_menu_log "[LLM-RESPONSE] empty — all models failed"
        echo -e "${C_MARK_BLOCK:-}✖ Não foi possível analisar as alterações (todos os modelos falharam).${R:-}" >&2
        return 1
    fi

    local raw_size=${#llm_response}
    local first_chars
    first_chars=$(echo "$llm_response" | head -c 500 | tr '\n' ' ')
    dotfiles_menu_log "[LLM-RESPONSE] raw_size=${raw_size}, first_chars=${first_chars}"

    # Limpa markdown fences se presentes
    local json_clean
    local had_fences=false
    if echo "$llm_response" | grep -q '```'; then
        had_fences=true
    fi
    json_clean=$(echo "$llm_response" | sed 's/^```json$//g; s/^```$//g' | awk 'NF')

    # Valida que é JSON válido
    dotfiles_menu_log "[LLM-PARSE] markdown_fences_removed=${had_fences}, validating JSON..."
    if ! echo "$json_clean" | jq empty 2>/dev/null; then
        dotfiles_menu_log "[LLM-PARSE] INVALID JSON"
        echo -e "${C_MARK_BLOCK:-}✖ Resposta da LLM não é JSON válido. Tente novamente.${R:-}" >&2
        echo -e "${C_FILE_PATH:-}Resposta recebida: $(echo "$llm_response" | head -5)${R:-}" >&2
        return 1
    fi
    dotfiles_menu_log "[LLM-PARSE] valid=true"

    echo "$json_clean"
}

# Executa os commits agrupados pelo bash (sem eval, sem LLM gerando código).
# Cada commit inclui a assinatura obrigatória Verified-By.
dotfiles_menu_execute_commits() {
    local repo_root="$1"
    local json_groups="$2"
    local group_count
    group_count=$(echo "$json_groups" | jq '. | length')

    dotfiles_menu_log "[GROUPS] count=${group_count}"
    dotfiles_menu_log "[GROUPS] full_json=$(echo "$json_groups" | jq -c .)"

    if (( group_count == 0 )); then
        dotfiles_menu_log "[GROUPS] empty — no groups suggested"
        echo -e "${C_MARK_NONE:-}⚠ Nenhum grupo de commit sugerido.${R:-}"
        return 0
    fi

    echo -e "${C_MARK_INST:-}📦 ${group_count} commit(s) propostos:${R:-}"
    echo ""

    local i type scope desc files_list msg
    for (( i=0; i<group_count; i++ )); do
        type=$(echo "$json_groups" | jq -r ".[$i].type")
        scope=$(echo "$json_groups" | jq -r ".[$i].scope")
        desc=$(echo "$json_groups" | jq -r ".[$i].description")
        files_list=$(echo "$json_groups" | jq -r ".[$i].files | join(\", \")")
        msg="${type}(${scope}): ${desc}"

        dotfiles_menu_log "[GROUP-${i}] type=${type}, scope=${scope}, desc=${desc}"
        dotfiles_menu_log "[GROUP-FILES-${i}] $(echo "$json_groups" | jq -c ".[$i].files")"

        echo -e "  ${B:-}[$((i+1))]${R:-} ${C_MARK_INST:-}${msg}${R:-}"
        echo -e "     ${C_FILE_PATH:-}Arquivos: ${files_list}${R:-}"
        echo ""
    done

    echo -e "${B:-}╭─────────────────────────────────────────────────────────────────╮${R:-}"
    echo -e "${B:-}│ ⚠  Revise os commits acima com atenção antes de confirmar.       │${R:-}"
    echo -e "${B:-}╰─────────────────────────────────────────────────────────────────╯${R:-}"
    echo ""

    local ans
    read -r -p "Realizar estes commits? (sim/não): " ans || true
    if ! dotfiles_menu_is_yes "$ans"; then
        dotfiles_menu_log "[EXEC] user cancelled"
        echo "Commit cancelado."
        return 0
    fi

    dotfiles_menu_log "[EXEC] user confirmed, starting execution"

    echo ""
    echo -e "${B:-}🚀 Executando commits...${R:-}"
    echo ""

    local success=0 failed=0
    for (( i=0; i<group_count; i++ )); do
        type=$(echo "$json_groups" | jq -r ".[$i].type")
        scope=$(echo "$json_groups" | jq -r ".[$i].scope")
        desc=$(echo "$json_groups" | jq -r ".[$i].description")
        msg="${type}(${scope}): ${desc}"

        local -a files_arr
        mapfile -t files_arr < <(echo "$json_groups" | jq -r ".[$i].files[]")

        # Filtra arquivos que realmente existem no repo
        local -a valid_files=()
        local f
        for f in "${files_arr[@]}"; do
            if [[ -e "$repo_root/$f" ]]; then
                valid_files+=("$f")
            else
                dotfiles_menu_log "[EXEC-INVALID] ${f} — file does not exist, skipping"
                echo -e "${C_MARK_NONE:-}  ⚠ Arquivo não encontrado (pulando): ${f}${R:-}"
            fi
        done

        if (( ${#valid_files[@]} == 0 )); then
            dotfiles_menu_log "[EXEC-COMMIT] ${msg} — no valid files, skipping"
            echo -e "${C_MARK_BLOCK:-}✖ Nenhum arquivo válido para o commit: ${msg}${R:-}"
            (( failed++ ))
            continue
        fi

        dotfiles_menu_log "[EXEC-ADD] ${valid_files[*]}"
        echo -e "${B:-}  [${i}]${R:-} ${C_MARK_INST:-}git add${R:-} ${valid_files[*]}"
        git -C "$repo_root" add -- "${valid_files[@]}"

        local commit_msg="${msg}

Verified-By: dotfiles-secure-commit"

        dotfiles_menu_log "[EXEC-COMMIT] ${msg}"
        echo -e "${B:-}  [${i}]${R:-} ${C_MARK_COMMIT:-}git commit -m \"${msg}\"${R:-}"
        if git -C "$repo_root" commit -m "$commit_msg" -- "${valid_files[@]}"; then
            dotfiles_menu_log "[EXEC-RESULT] success"
            echo -e "  ${C_MARK_INST:-}✅ Commit criado.${R:-}"
            (( success++ ))
        else
            dotfiles_menu_log "[EXEC-RESULT] failed (exit $?)"
            echo -e "  ${C_MARK_BLOCK:-}✖ Erro no commit.${R:-}"
            (( failed++ ))
        fi
        echo ""
    done

    echo ""
    if (( success > 0 )); then
        echo -e "${C_MARK_INST:-}✅ ${success} commit(s) criado(s) com sucesso!${R:-}"
    fi
    if (( failed > 0 )); then
        echo -e "${C_MARK_BLOCK:-}✖ ${failed} commit(s) falharam.${R:-}"
    fi

    dotfiles_menu_log "[SESSION] completed: ${success} success, ${failed} failed"

    # Opção de push após commits
    if (( success > 0 )); then
        echo ""
        read -r -p "Deseja fazer o 'git push' agora? (sim/não): " ans || true
        if dotfiles_menu_is_yes "$ans"; then
            dotfiles_menu_log "[PUSH] user requested push"
            echo -e "${B:-}🚀 Enviando para o repositório remoto...${R:-}"
            git -C "$repo_root" push
            if [[ $? -eq 0 ]]; then
                dotfiles_menu_log "[PUSH] success"
                echo -e "${C_MARK_INST:-}✅ Push concluído!${R:-}"
            else
                dotfiles_menu_log "[PUSH] failed"
                echo -e "${C_MARK_BLOCK:-}✖ Erro no push. Verifique o seu terminal/git.${R:-}"
            fi
        fi
    fi
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

# Smart Commit adaptado da skill dotfiles-secure-commit.
# Fluxo: 1) coleta diff (bash) → 2) auditoria + grupos (1 chamada LLM) → 3) executa commits (bash)
dotfiles_menu_smart_commit() {
    local repo_root api_key
    local -a models
    repo_root="$(dotfiles_repo_root)"

    # Inicializa logging
    dotfiles_menu_log_init
    dotfiles_menu_log "[SESSION] smart_commit started"
    dotfiles_menu_log "[SESSION] log_file=${DOTFILES_COMMIT_LOG}"

    if ! dotfiles_menu_check_deps jq curl; then
        dotfiles_menu_log "[ERROR] missing dependencies (jq or curl)"
        return 0
    fi

    # Etapa 1 — Analisar estado
    local status_output
    status_output=$(git -C "$repo_root" status --porcelain 2>/dev/null)
    if [[ -z "$status_output" ]]; then
        dotfiles_menu_log "[STATUS] no changes detected"
        echo -e "${C_MARK_NONE:-}⚠ Nenhuma alteração detectada no repositório.${R:-}"
        return 0
    fi

    dotfiles_menu_log "[STATUS] $(echo "$status_output" | wc -l) files: $(echo "$status_output" | tr '\n' ' | ')"

    # Carrega API key
    if ! dotfiles_menu_load_api_key api_key models; then
        dotfiles_menu_log "[ERROR] failed to load API key"
        return 0
    fi
    dotfiles_menu_log "[SESSION] api_key loaded, model=${models[0]}"

    echo -e "${B:-}✨ Analisando alterações (skill dotfiles-secure-commit)...${R:-}"
    echo ""

    # Coleta contexto
    local full_context
    full_context="$(dotfiles_menu_collect_diff "$repo_root")"

    echo -e "${C_FILE_PATH:-}📊 Status: $(echo "$status_output" | wc -l) arquivo(s) alterado(s)${R:-}"
    echo -e "${B:-}🤖 Enviando para auditoria + agrupamento...${R:-}"
    echo ""

    # Etapa 2 — Auditoria + Agrupamentos (1 chamada LLM)
    local audit_json
    audit_json=$(dotfiles_menu_call_llm_audit "$api_key" "${models[@]}" "$full_context") || {
        dotfiles_menu_log "[ERROR] LLM audit call failed"
        return 0
    }

    # Parse da auditoria
    local audit_status audit_findings_count
    audit_status=$(echo "$audit_json" | jq -r '.audit.status')
    audit_findings_count=$(echo "$audit_json" | jq '.audit.findings | length')

    dotfiles_menu_log "[AUDIT] status=${audit_status}, findings_count=${audit_findings_count}"

    # Etapa 3 — Tratar resultado da auditoria
    if [[ "$audit_status" == "fail" ]]; then
        dotfiles_menu_log "[AUDIT-BLOCK] commit blocked due to security findings"
        echo -e "${B:-}╔══════════════════════════════════════════════════════════════╗${R:-}"
        echo -e "${B:-}║  🔴  BLOQUEIO DE SEGURANÇA — Segredo Detectado               ║${R:-}"
        echo -e "${B:-}╚══════════════════════════════════════════════════════════════╝${R:-}"
        echo ""

        local j finding_level finding_file finding_reason
        for (( j=0; j<audit_findings_count; j++ )); do
            finding_level=$(echo "$audit_json" | jq -r ".audit.findings[$j].level")
            finding_file=$(echo "$audit_json" | jq -r ".audit.findings[$j].file")
            finding_reason=$(echo "$audit_json" | jq -r ".audit.findings[$j].reason")
            dotfiles_menu_log "[AUDIT-BLOCK] ${finding_level} ${finding_file}: ${finding_reason}"
            echo -e "  ${finding_level} ${C_MARK_BLOCK:-}${finding_file}${R:-}"
            echo -e "     ${C_FILE_PATH:-}${finding_reason}${R:-}"
            echo ""
        done

        echo "O commit foi bloqueado por conter informações sensíveis."
        echo ""
        echo "Como resolver:"
        echo "1. Remova os segredos do arquivo indicado"
        echo "2. Mova segredos para um arquivo local (ex: ~/.secrets) e faça source"
        echo "3. Use variáveis de ambiente"
        dotfiles_menu_log "[SESSION] ended: blocked by audit"
        return 0
    fi

    if [[ "$audit_status" == "warn" ]]; then
        dotfiles_menu_log "[AUDIT-WARN] warning level findings, asking user confirmation"
        echo -e "${B:-}╔══════════════════════════════════════════════════════════════╗${R:-}"
        echo -e "${B:-}║  🟡  ATENÇÃO — Possíveis problemas detectados                ║${R:-}"
        echo -e "${B:-}╚══════════════════════════════════════════════════════════════╝${R:-}"
        echo ""

        local j finding_level finding_file finding_reason
        for (( j=0; j<audit_findings_count; j++ )); do
            finding_level=$(echo "$audit_json" | jq -r ".audit.findings[$j].level")
            finding_file=$(echo "$audit_json" | jq -r ".audit.findings[$j].file")
            finding_reason=$(echo "$audit_json" | jq -r ".audit.findings[$j].reason")
            dotfiles_menu_log "[AUDIT-WARN] ${finding_level} ${finding_file}: ${finding_reason}"
            echo -e "  ${finding_level} ${C_FILE_PATH:-}${finding_file}${R:-}"
            echo -e "     ${C_FILE_PATH:-}${finding_reason}${R:-}"
            echo ""
        done

        local ans
        read -r -p "Deseja continuar mesmo assim? (sim/não): " ans || true
        if ! dotfiles_menu_is_yes "$ans"; then
            dotfiles_menu_log "[SESSION] ended: user cancelled after audit warning"
            echo "Commit cancelado."
            return 0
        fi
        echo ""
    fi

    # Extrai grupos (pode estar vazio se audit=fail)
    local groups_json
    groups_json=$(echo "$audit_json" | jq '.groups // []')

    local group_count
    group_count=$(echo "$groups_json" | jq '. | length')

    dotfiles_menu_log "[GROUPS] extracted_count=${group_count}"

    if (( group_count == 0 )); then
        dotfiles_menu_log "[GROUPS] empty — no groups suggested by LLM"
        echo -e "${C_MARK_NONE:-}⚠ Nenhum grupo de commit sugerido pela análise.${R:-}"
        echo -e "${C_FILE_PATH:-}Log da sessão: ${DOTFILES_COMMIT_LOG}${R:-}"
        return 0
    fi

    # Etapa 4 — Executar commits
    dotfiles_menu_execute_commits "$repo_root" "$groups_json"

    dotfiles_menu_log "[SESSION] log saved to: ${DOTFILES_COMMIT_LOG}"
}

# Reconhece o comando "push" no menu principal.
# Retorna 0 se reconheceu (tratado ou cancelado); 1 se não reconheceu.
dotfiles_menu_try_push() {
    local trimmed=$1
    if [[ "${trimmed,,}" == "push" ]]; then
        dotfiles_menu_push
        return 0
    fi
    return 1
}

# Realiza o git push do repositório
dotfiles_menu_push() {
    local repo_root
    repo_root="$(dotfiles_repo_root)"
    echo ""
    echo -e "${B:-}🚀 Enviando para o repositório remoto...${R:-}"
    git -C "$repo_root" push
    if [[ $? -eq 0 ]]; then
        echo -e "${C_MARK_INST:-}✅ Push concluído com sucesso!${R:-}"
    else
        echo -e "${C_MARK_BLOCK:-}✖ Erro no push. Verifique se o repositório remoto está configurado e acessível.${R:-}"
    fi
    echo ""
}

# Reconhece o comando "pull" no menu principal.
# Retorna 0 se reconheceu (tratado ou cancelado); 1 se não reconheceu.
dotfiles_menu_try_pull() {
    local trimmed=$1
    if [[ "${trimmed,,}" == "pull" ]]; then
        dotfiles_menu_pull
        return 0
    fi
    return 1
}

# Executa git pull --ff-only para atualizar o repositório.
dotfiles_menu_pull() {
    local repo_root
    repo_root="$(dotfiles_repo_root)"
    echo ""
    echo -e "${B:-}📡 Buscando e aplicando atualizações do repositório remoto...${R:-}"
    echo ""
    if dotfiles_repo_pull; then
        echo ""
        echo -e "${C_MARK_INST:-}✅ Repositório atualizado com sucesso!${R:-}"
    else
        echo ""
        echo -e "${C_MARK_BLOCK:-}✖ Erro ao atualizar. Verifique se há conflitos ou conectividade.${R:-}"
    fi
    echo ""
}

dotfiles_menu_commit_file() {
    local file=$1
    local key_file data_dir repo_root api_key diff_output response commit_msg ans

    dotfiles_menu_log_init
    dotfiles_menu_log "[COMMIT-FILE] started for ${file}"
    
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
            dotfiles_menu_log "[COMMIT-FILE] gemini CLI not found"
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
            dotfiles_menu_log "[COMMIT-FILE] no diff for ${rel_path}"
            return 0
        fi

        dotfiles_menu_log "[COMMIT-FILE] diff_size=${#diff_for_gemini} for ${rel_path}"

        local gemini_msg
        gemini_msg=$(GEMINI_CLI_TRUST_WORKSPACE=true gemini -p \
            "Analise este diff git e gere APENAS uma mensagem de commit usando o padrão Conventional Commits. Responda SOMENTE com a mensagem de commit, sem explicações, sem blocos de código, sem prefixos como 'Resposta:'. Apenas a mensagem pura.

${diff_for_gemini}" 2>/dev/null)

        if [[ -z "$gemini_msg" ]]; then
            echo -e "${C_MARK_BLOCK:-}✖ Não foi possível gerar a mensagem de commit via Gemini CLI.${R:-}"
            dotfiles_menu_log "[COMMIT-FILE] gemini CLI returned empty"
            return 0
        fi

        dotfiles_menu_log "[COMMIT-FILE] gemini_msg=${gemini_msg}"

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
            dotfiles_menu_log "[COMMIT-FILE] user cancelled"
            echo "Commit cancelado."
            return 0
        fi

        git -C "$repo_root" add -- "$rel_path"
        git -C "$repo_root" commit -m "$gemini_msg

Verified-By: dotfiles-secure-commit" -- "$rel_path"
        dotfiles_menu_log "[COMMIT-FILE] committed: ${gemini_msg}"
        echo "Commit realizado com sucesso!"
        
        echo ""
        read -r -p "Deseja fazer o 'git push' agora? (sim/não): " ans || true
        if dotfiles_menu_is_yes "$ans"; then
            echo -e "${B:-}🚀 Enviando para o repositório remoto...${R:-}"
            git -C "$repo_root" push
        fi
        
        dotfiles_menu_log "[SESSION] log saved to: ${DOTFILES_COMMIT_LOG}"
        return 0
    elif [[ -n "$commit_opt" && "$commit_opt" != "1" ]]; then
        dotfiles_menu_log "[COMMIT-FILE] user cancelled (option ${commit_opt})"
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
        dotfiles_menu_log "[COMMIT-FILE-API] missing dependencies"
        return 1
    fi

    echo -e "${B:-}✨ Gerando mensagem de commit para ${file}...${R:-}"
    
    # Obter o diff do arquivo específico
    local rel_path="data/${file}"
    diff_output="$(git -C "$repo_root" diff HEAD -- "$rel_path" 2>/dev/null)"
    
    if [[ -z "$diff_output" ]]; then
        echo -e "${C_MARK_NONE:-}⚠ Nenhuma alteração detectada para $file pelo git ou arquivo não rastreado.${R:-}"
        dotfiles_menu_log "[COMMIT-FILE-API] no diff for ${rel_path}"
        return 0
    fi

    # Check for diff size (e.g., > 100KB)
    local diff_size=${#diff_output}
    if (( diff_size > 100000 )); then
        echo -e "${C_MARK_BLOCK:-}✖ Diff muito grande (${diff_size} bytes).${R:-}" >&2
        dotfiles_menu_log "[COMMIT-FILE-API] diff too large: ${diff_size} bytes"
        return 0
    fi

    dotfiles_menu_log "[COMMIT-FILE-API] diff_size=${diff_size} for ${rel_path}"
    
    local json_payload
    json_payload=$(jq -n --arg diff "$diff_output" '{
      "contents": [{
        "parts": [{
          "text": ("Você é um assistente que escreve mensagens de commit baseadas em diffs de git. Escreva APENAS a mensagem de commit usando o padrão Conventional Commits. Seja conciso. Aqui está o diff:\n\n" + $diff)
        }]
      }]
    }') || { echo -e "${C_MARK_BLOCK:-}✖ Erro ao preparar JSON.${R:-}" >&2; dotfiles_menu_log "[COMMIT-FILE-API] jq payload failed"; return 1; }
    
    commit_msg=""
    local current_model
    for current_model in "${models[@]}"; do
        [[ "$current_model" != "${models[0]}" ]] && echo -e "${C_LINK_STATUS_UNLINKED:-}  ↪ Tentando fallback: ${current_model}...${R:-}"

        # Evita erro de limite de tamanho de argumento (ARG_MAX) passando o JSON via stdin
        response=$(echo "$json_payload" | curl -s -X POST -H "Content-Type: application/json" \
            -d @- \
            "https://generativelanguage.googleapis.com/v1beta/models/${current_model}:generateContent?key=${api_key}")
        
        if [[ $? -ne 0 ]]; then
            dotfiles_menu_log "[COMMIT-FILE-API] curl failed for ${current_model}"
            continue # Erro de rede, tenta o próximo
        fi
            
        local api_error
        api_error=$(echo "$response" | jq -r '.error.message // empty' 2>/dev/null)
        
        if [[ -n "$api_error" ]]; then
            # Se a chave for expressamente inválida, paramos. Caso contrário (quota, modelo inexistente, etc), tentamos o próximo fallback.
            if [[ "${api_error,,}" == *"api key"* || "${api_error,,}" == *"api_key"* ]]; then
                echo -e "${C_MARK_BLOCK:-}✖ Erro de Autenticação na API: $api_error${R:-}" >&2
                dotfiles_menu_log "[COMMIT-FILE-API] auth error: ${api_error}"
                break
            fi
            # Loga o aviso se não for cota pura e tenta os próximos fallbacks
            [[ "${api_error,,}" == *"quota"* || "${api_error,,}" == *"limit"* || "${api_error,,}" == *"high demand"* || "${api_error,,}" == *"overloaded"* || "${api_error,,}" == *"temporarily"* ]] || \
                echo -e "${C_MARK_BLOCK:-}⚠ Aviso na API (${current_model}): $api_error (tentando fallback)...${R:-}" >&2
            dotfiles_menu_log "[COMMIT-FILE-API] api warning (${current_model}): ${api_error}"
            continue
        fi

        commit_msg=$(echo "$response" | jq -r '.candidates[0].content.parts[0].text // empty' 2>/dev/null)
        [[ -n "$commit_msg" ]] && break
    done
    
    if [[ -z "$commit_msg" ]]; then
        echo -e "${C_MARK_BLOCK:-}✖ Não foi possível gerar a mensagem de commit (todos os modelos falharam).${R:-}" >&2
        dotfiles_menu_log "[COMMIT-FILE-API] all models failed"
        return 0
    fi
    
    dotfiles_menu_log "[COMMIT-FILE-API] generated msg: ${commit_msg}"
    
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
        dotfiles_menu_log "[COMMIT-FILE-API] user cancelled"
        echo "Commit cancelado."
        return 0
    fi
    
    git -C "$repo_root" commit -m "$commit_msg

Verified-By: dotfiles-secure-commit" -- "$rel_path"
    dotfiles_menu_log "[COMMIT-FILE-API] committed: ${commit_msg}"
    echo "Commit realizado com sucesso!"
    
    echo ""
    read -r -p "Deseja fazer o 'git push' agora? (sim/não): " ans || true
    if dotfiles_menu_is_yes "$ans"; then
        echo -e "${B:-}🚀 Enviando para o repositório remoto...${R:-}"
        git -C "$repo_root" push
    fi

    dotfiles_menu_log "[SESSION] log saved to: ${DOTFILES_COMMIT_LOG}"
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
            echo "Não dá para instalar: crie primeiro $(dotfiles_data_dir)/${file}"
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

# Reconhece o comando "install" ou "install-all" no menu principal.
# Executa dotfiles_link_from_dotfile_names para todos os dotfiles.
# Retorna 0 se reconheceu (tratado); 1 se não reconheceu.
dotfiles_menu_try_install_all() {
    local trimmed=$1
    if [[ "${trimmed,,}" == "install-all" ]]; then
        dotfiles_menu_install_all
        return 0
    fi
    return 1
}

dotfiles_menu_install_all() {
    echo ""
    echo -e "${B:-}🚀 Instalando todos os dotfiles...${R:-}"
    echo ""
    dotfiles_link_from_dotfile_names
    echo ""
    echo -e "${C_MARK_INST:-}✅ Todos os dotfiles foram instalados.${R:-}"
    echo ""
}

# Reconhece o comando "term" ou "terminal" no menu principal.
# Retorna 0 se reconheceu (tratado); 1 se não reconheceu.
dotfiles_menu_try_open_terminal() {
    local trimmed=$1
    if [[ "${trimmed,,}" == "term" || "${trimmed,,}" == "terminal" ]]; then
        dotfiles_menu_open_terminal
        return 0
    fi
    return 1
}

# Abre um novo terminal no diretório do repositório de dotfiles.
dotfiles_menu_open_terminal() {
    local repo_root
    repo_root="$(dotfiles_repo_root)"

    # Respeitar variável de ambiente se definida
    if [[ -n "${DOTFILES_MENU_TERMINAL:-}" ]]; then
        if command -v "$DOTFILES_MENU_TERMINAL" >/dev/null 2>&1; then
            echo ""
            echo -e "${B:-}🖥️  Abrindo terminal ($DOTFILES_MENU_TERMINAL) em ${repo_root}...${R:-}"
            "$DOTFILES_MENU_TERMINAL" "$repo_root" >/dev/null 2>&1 & disown
            echo -e "${C_MARK_INST:-}✅ Terminal iniciado.${R:-}"
            echo ""
            return
        fi
    fi

    # Lista de terminais conhecidos e flags para diretório de trabalho
    # Formato: "comando|flag_cwd"
    local -a terminals=(
        "wezterm|start --cwd"
        "ghostty|--working-directory"
        "kitty|--directory"
        "alacritty|--working-directory"
        "foot|--working-directory"
        "kgx|--working-directory"
        "gnome-terminal|--working-directory"
        "tilix|--working-directory"
        "xfce4-terminal|--working-directory"
        "konsole|--workdir"
        "terminator|--working-directory"
        "x-terminal-emulator|-e"
    )

    local entry cmd flags
    for entry in "${terminals[@]}"; do
        cmd="${entry%%|*}"
        flags="${entry#*|}"

        if command -v "$cmd" >/dev/null 2>&1; then
            echo ""
            echo -e "${B:-}🖥️  Abrindo terminal ($cmd) em ${repo_root}...${R:-}"
            
            # Tratamento especial para x-terminal-emulator e casos genéricos
            if [[ "$cmd" == "x-terminal-emulator" ]]; then
                # Tenta abrir um shell e mudar de diretório
                "$cmd" -e bash -c "cd '$repo_root'; exec \$SHELL -l" >/dev/null 2>&1 & disown
            else
                # A maioria dos terminais modernos aceita: cmd --flag cwd
                # Nota: gnome-terminal precisa de -- antes do -e, mas --working-directory geralmente funciona direto
                if [[ "$cmd" == "gnome-terminal" ]]; then
                    "$cmd" "$flags" "$repo_root" >/dev/null 2>&1 & disown
                else
                    "$cmd" $flags "$repo_root" >/dev/null 2>&1 & disown
                fi
            fi
            
            echo -e "${C_MARK_INST:-}✅ Terminal iniciado.${R:-}"
            echo ""
            return
        fi
    done

    # Fallback
    echo ""
    echo -e "${C_MARK_BLOCK:-}✖ Nenhum terminal compatível encontrado.${R:-}"
    echo -e "  Abra manualmente e execute: cd ${repo_root}"
    echo ""
}
