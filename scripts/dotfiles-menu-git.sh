#!/usr/bin/env bash
# Comandos do submenu git: config, SSH, remote, gh, setup wizard
# shellcheck disable=SC2154  # C_MARK_*, C_FILE_PATH, R, B vêm de dotfiles-menu-ui.sh

# ─── Cache TTL ────────────────────────────────────────────────────────────
DOTFILES_CACHE_GH_STATUS=""
DOTFILES_CACHE_GH_STATUS_TS=0
DOTFILES_CACHE_TTL=60

dotfiles_git_gh_cached_status() {
    local _now
    _now=$(date +%s)
    if (( _now - DOTFILES_CACHE_GH_STATUS_TS < DOTFILES_CACHE_TTL )) && [[ -n "$DOTFILES_CACHE_GH_STATUS" ]]; then
        echo "$DOTFILES_CACHE_GH_STATUS"
        return
    fi
    if ! command -v gh >/dev/null 2>&1; then
        DOTFILES_CACHE_GH_STATUS="not_installed"
    elif gh auth status &>/dev/null; then
        DOTFILES_CACHE_GH_STATUS="authed"
    else
        DOTFILES_CACHE_GH_STATUS="unauthed"
    fi
    DOTFILES_CACHE_GH_STATUS_TS=$_now
    echo "$DOTFILES_CACHE_GH_STATUS"
}

dotfiles_git_invalidate_cache() {
    DOTFILES_CACHE_GH_STATUS=""
    DOTFILES_CACHE_GH_STATUS_TS=0
}

# ─── Helpers ──────────────────────────────────────────────────────────────

dotfiles_git_setup_needed() {
    if ! command -v git >/dev/null 2>&1; then
        return 0
    fi
    if [[ -z "$(git config --global user.name 2>/dev/null)" ]] || \
       [[ -z "$(git config --global user.email 2>/dev/null)" ]]; then
        return 0
    fi
    for _gk in "$HOME/.ssh/id_ed25519" "$HOME/.ssh/id_rsa" "$HOME/.ssh/id_ecdsa"; do
        [[ -f "$_gk" ]] && return 1
    done
    return 0
}

dotfiles_git_print_setup_banner() {
    if dotfiles_git_setup_needed; then
        local _w _pad
        _w="$(dotfiles_menu_ui_table_width)"
        printf -v _pad '%*s' "$_w" ''
        _pad="${_pad// /─}"
        echo "$_pad"
        echo -e "${C_MARK_NONE:-}⚠ Git ou SSH não configurados. Digite 'git' para setup.${R:-}"
        echo "$_pad"
    fi
}

dotfiles_git_print_status_bar() {
    local _branch _remote _name _email _ssh_status _gh_status
    local _r=${R:-} _b=${B:-} _path=${C_FILE_PATH:-} _green=${C_MARK_INST:-} _yellow=${C_MARK_NONE:-}

    _branch="$(git -C "$(dotfiles_repo_root)" branch --show-current 2>/dev/null || echo 'N/A')"
    _remote="$(git -C "$(dotfiles_repo_root)" remote get-url origin 2>/dev/null || echo '')"
    _name="$(git config --global user.name 2>/dev/null || echo '')"
    _email="$(git config --global user.email 2>/dev/null || echo '')"

    if dotfiles_git_ssh_find_key >/dev/null 2>&1; then
        _ssh_status="${_green}✓${_r}"
    else
        _ssh_status="${_yellow}✗${_r}"
    fi

    _gh_status="$(dotfiles_git_gh_cached_status)"
    case "$_gh_status" in
        authed)        _gh_status="${_green}✓${_r}" ;;
        unauthed)      _gh_status="${_yellow}✗${_r}" ;;
        not_installed) _gh_status="${_path}–${_r}" ;;
        *)             _gh_status="${_path}?${_r}" ;;
    esac

    echo "  ${_b}${_branch}${_r}  ${_path}←${_r}  ${_path}${_remote}${_r}"
    echo "  ${_name}${_name:+ }<${_email}>  ${_path}│${_r}  SSH: ${_ssh_status}  ${_path}│${_r}  gh: ${_gh_status}"
}

# ─── Git: Status ──────────────────────────────────────────────────────────

dotfiles_git_cmd_status() {
    local repo_root
    repo_root="$(dotfiles_repo_root)"
    echo ""
    echo -e "${B:-}📊 Status do repositório${R:-}"
    echo -e "${C_FILE_PATH:-}Branch:${R:-} $(git -C "$repo_root" branch --show-current 2>/dev/null || echo 'N/A')"

    local _ahead _behind
    if read -r _ahead _behind < <(git -C "$repo_root" rev-list --left-right --count "HEAD...@{u}" 2>/dev/null); then
        echo -e "${C_FILE_PATH:-}Relação com remoto:${R:-} ${_ahead} ahead, ${_behind} behind"
    fi
    local _url
    _url="$(git -C "$repo_root" remote get-url origin 2>/dev/null || true)"
    [[ -n "$_url" ]] && echo -e "${C_FILE_PATH:-}Remote:${R:-} $_url"

    echo ""
    echo -e "${C_FILE_PATH:-}Working tree:${R:-}"
    git -C "$repo_root" status --short 2>/dev/null | sed 's/^/  /'
    local _dirty
    _dirty="$(git -C "$repo_root" status --porcelain 2>/dev/null | wc -l)"
    if [[ "$_dirty" -eq 0 ]]; then
        echo "  (limpo)"
    fi

    echo ""
    echo -e "${C_FILE_PATH:-}Último commit:${R:-}"
    git -C "$repo_root" log --oneline -1 2>/dev/null | sed 's/^/  /' || echo "  (nenhum)"
}

# ─── Git: Config ──────────────────────────────────────────────────────────

dotfiles_git_cmd_config() {
    echo ""
    echo -e "${B:-}⚙ Configuração Git global${R:-}"
    echo ""
    echo -e "${C_FILE_PATH:-}git config --global --list:${R:-}"
    git config --global --list 2>/dev/null | sed 's/^/  /' || echo "  (vazia)"
    echo ""
    echo -e "${C_FILE_PATH:-}data/gitconfig (versionado):${R:-}"
    if [[ -f "$(dotfiles_data_dir)/gitconfig" ]]; then
        cat "$(dotfiles_data_dir)/gitconfig" 2>/dev/null | sed 's/^/  /'
    else
        echo "  (não existe)"
    fi
    echo ""
    echo "${B}Opções:${R}"
    echo "  1) Editar data/gitconfig (versionado)"
    echo "  2) Definir user.name e user.email (git config --global)"
    echo "  v) Voltar"
    local _oc
    read -r -p "Escolha: " _oc || true
    case "${_oc,,}" in
        1)
            "${EDITOR:-nano}" "$(dotfiles_data_dir)/gitconfig"
            dotfiles_link_one "gitconfig" 2>/dev/null || true
            echo -e "${C_MARK_INST:-}✅ data/gitconfig atualizado.${R:-}"
            ;;
        2)
            local _name _email
            read -r -p "Nome para commits: " _name
            read -r -p "Email para commits: " _email
            [[ -n "$_name" ]] && git config --global user.name "$_name"
            [[ -n "$_email" ]] && git config --global user.email "$_email"
            echo -e "${C_MARK_INST:-}✅ Git config atualizado.${R:-}"
            ;;
    esac
}

# ─── SSH ──────────────────────────────────────────────────────────────────

dotfiles_git_ssh_find_key() {
    for _k in "$HOME/.ssh/id_ed25519" "$HOME/.ssh/id_rsa" "$HOME/.ssh/id_ecdsa" "$HOME/.ssh/id_ed25519_sk"; do
        [[ -f "$_k" ]] && { echo "$_k"; return 0; }
    done
    return 1
}

dotfiles_git_ssh_copy_key() {
    local _pub="$1"
    if command -v xclip >/dev/null 2>&1; then
        xclip -selection clipboard < "$_pub"
        echo -e "${C_MARK_INST:-}✅ Chave copiada (xclip).${R:-}"
    elif command -v xsel >/dev/null 2>&1; then
        xsel --clipboard < "$_pub"
        echo -e "${C_MARK_INST:-}✅ Chave copiada (xsel).${R:-}"
    elif command -v wl-copy >/dev/null 2>&1; then
        wl-copy < "$_pub"
        echo -e "${C_MARK_INST:-}✅ Chave copiada (wl-copy).${R:-}"
    else
        echo -e "${C_MARK_NONE:-}⚠ Nenhum clipboard tool encontrado. Copie manualmente:${R:-}"
        echo ""
        cat "$_pub"
    fi
}

dotfiles_git_ssh_eval_agent() {
    if [[ -z "${SSH_AUTH_SOCK:-}" ]] || ! ssh-add -l &>/dev/null; then
        eval "$(ssh-agent -s)" >/dev/null 2>&1 || true
    fi
}

dotfiles_git_ssh_generate_key() {
    local _email _ans _ask
    _email="$(git config --global user.email 2>/dev/null || echo '')"
    _email="${_email:-$USER@$(hostname)}"

    echo ""
    read -r -p "Email para a chave SSH [${_email}]: " _ans
    _email="${_ans:-$_email}"

    mkdir -p "$HOME/.ssh"
    chmod 700 "$HOME/.ssh"

    # Warn if key already exists
    if [[ -f "$HOME/.ssh/id_ed25519" ]]; then
        echo -e "${C_MARK_BLOCK:-}⚠ ~/.ssh/id_ed25519 já existe — será sobrescrita!${R:-}"
        local _conf
        read -r -p "Tem certeza? (s/N): " _conf
        if ! dotfiles_menu_is_yes "$_conf"; then
            echo "Cancelado."
            return
        fi
    fi

    echo -e "${C_FILE_PATH:-}Gerando chave ed25519...${R:-}"
    if ssh-keygen -t ed25519 -C "$_email" -f "$HOME/.ssh/id_ed25519"; then
        echo -e "${C_MARK_INST:-}✅ Chave gerada: ~/.ssh/id_ed25519${R:-}"
        dotfiles_git_ssh_eval_agent
        ssh-add "$HOME/.ssh/id_ed25519" 2>/dev/null || true

        echo ""
        echo -e "${B:-}Deseja copiar a chave pública para o clipboard?${R:-}"
        read -r -p "Assim pode colar em https://github.com/settings/keys (s/N): " _ask
        if dotfiles_menu_is_yes "$_ask"; then
            dotfiles_git_ssh_copy_key "$HOME/.ssh/id_ed25519.pub"
        else
            echo ""
            echo -e "${C_FILE_PATH:-}Chave pública:${R:-}"
            cat "$HOME/.ssh/id_ed25519.pub"
        fi
    else
        echo -e "${C_MARK_BLOCK:-}✖ Erro ao gerar chave.${R:-}"
    fi
}

dotfiles_git_ssh_test_connection() {
    echo ""
    echo -e "${C_FILE_PATH:-}Testando SSH com GitHub...${R:-}"
    ssh -T git@github.com -o StrictHostKeyChecking=no -o BatchMode=yes 2>&1 || true
    local _exit=$?
    if [[ $_exit -eq 1 ]]; then
        echo -e "${C_MARK_INST:-}✅ Conexão SSH com GitHub OK!${R:-}"
    else
        echo -e "${C_MARK_BLOCK:-}✖ Falha na conexão. Verifique:${R:-}"
        echo "  1) Chave adicionada em https://github.com/settings/keys"
        echo "  2) ssh-agent rodando (ssh-add -l)"
    fi
}

dotfiles_git_cmd_ssh() {
    echo ""
    echo -e "${B:-}🔑 Chave SSH${R:-}"
    echo ""

    local _key
    _key="$(dotfiles_git_ssh_find_key)" || true

    if [[ -n "$_key" ]]; then
        echo -e "${C_MARK_INST:-}  ✓ Chave encontrada:${R:-} $_key"
        echo ""
        echo -e "${C_FILE_PATH:-}Chave pública:${R:-}"
        cat "${_key}.pub" 2>/dev/null | sed 's/^/  /'
        echo ""
        echo "${B}Opções:${R}"
        echo "  1) Copiar chave pública para clipboard"
        echo "  2) Testar conexão SSH com GitHub"
        echo "  3) Gerar nova chave (sobrescreve)"
        echo "  v) Voltar"
    else
        echo -e "${C_MARK_NONE:-}  ⚠ Nenhuma chave SSH encontrada.${R:-}"
        echo ""
        echo "${B}Opções:${R}"
        echo "  1) Gerar chave SSH (ed25519)"
        echo "  v) Voltar"
    fi

    local _os
    read -r -p "Escolha: " _os || true
    case "${_os,,}" in
        1)
            if [[ -n "$_key" ]]; then
                dotfiles_git_ssh_copy_key "${_key}.pub"
            else
                dotfiles_git_ssh_generate_key
            fi
            ;;
        2) dotfiles_git_ssh_test_connection ;;
        3) dotfiles_git_ssh_generate_key ;;
    esac
}

# ─── Remote ───────────────────────────────────────────────────────────────

dotfiles_git_cmd_remote() {
    local repo_root
    repo_root="$(dotfiles_repo_root)"
    echo ""
    echo -e "${B:-}🌐 Remote URL${R:-}"
    echo ""
    git -C "$repo_root" remote -v 2>/dev/null | sed 's/^/  /' || echo "  (sem remote)"
    echo ""
    echo "${B}Opções:${R}"
    echo "  1) Alterar remote origin"
    echo "  v) Voltar"
    local _or
    read -r -p "Escolha: " _or || true
    if [[ "${_or,,}" == "1" ]]; then
        local _url
        read -r -p "Nova URL do remote origin: " _url
        if [[ -n "$_url" ]]; then
            git -C "$repo_root" remote set-url origin "$_url"
            echo -e "${C_MARK_INST:-}✅ Remote atualizado.${R:-}"
        fi
    fi
}

# ─── Log ──────────────────────────────────────────────────────────────────

dotfiles_git_cmd_log() {
    local repo_root
    repo_root="$(dotfiles_repo_root)"
    echo ""
    echo -e "${B:-}📜 Últimos commits${R:-}"
    echo ""
    git -C "$repo_root" log --oneline -15 2>/dev/null | sed 's/^/  /' || echo "  (nenhum commit)"
}

# ─── GitHub CLI ───────────────────────────────────────────────────────────

dotfiles_git_cmd_gh() {
    echo ""
    echo -e "${B:-}🐙 GitHub CLI (gh)${R:-}"
    echo ""

    if ! command -v gh >/dev/null 2>&1; then
        echo -e "${C_MARK_NONE:-}  ⚠ gh CLI não instalado.${R:-}"
        echo ""
        echo "${B}Opções:${R}"
        echo "  1) Instruções de instalação"
        echo "  v) Voltar"
        local _og
        read -r -p "Escolha: " _og || true
        if [[ "${_og,,}" == "1" ]]; then
            echo ""
            echo "Instale o GitHub CLI (precisa de sudo):"
            echo ""
            echo "  curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg"
            echo "  echo 'deb [signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main' | sudo tee /etc/apt/sources.list.d/github-cli.list"
            echo "  sudo apt update && sudo apt install gh"
            echo ""
            echo "Ou: https://github.com/cli/cli/releases"
        fi
        return
    fi

    if gh auth status &>/dev/null; then
        echo -e "${C_MARK_INST:-}  ✓ Autenticado${R:-}"
        gh auth status 2>&1 | grep "Logged in to" | sed 's/^/    /'
    else
        echo -e "${C_MARK_NONE:-}  ⚠ gh instalado, mas não autenticado.${R:-}"
    fi

    echo ""
    echo "${B}Opções:${R}"
    echo "  1) Autenticar (gh auth login)"
    echo "  v) Voltar"
    local _og
    read -r -p "Escolha: " _og || true
    if [[ "${_og,,}" == "1" ]]; then
        echo ""
        echo -e "${C_FILE_PATH:-}Executando gh auth login...${R:-}"
        gh auth login
        dotfiles_git_invalidate_cache
        echo -e "${C_MARK_INST:-}✅ Autenticação concluída.${R:-}"
    fi
}

# ─── Setup Wizard ─────────────────────────────────────────────────────────

dotfiles_git_cmd_setup() {
    echo ""
    echo -e "${B:-}🚀 Setup Git / SSH${R:-}"
    echo -e "${C_FILE_PATH:-}────────────────────────────────────────────${R:-}"
    echo ""

    # Passo 1: Git config
    if [[ -z "$(git config --global user.name 2>/dev/null)" ]] || \
       [[ -z "$(git config --global user.email 2>/dev/null)" ]]; then
        echo -e "${B:-}[1/4] Configurar Git global${R:-}"
        local _name _email
        _name="$(git config --global user.name 2>/dev/null || echo '')"
        _email="$(git config --global user.email 2>/dev/null || echo '')"

        read -r -p "  Nome para commits [${_name:-}]: " _ans_n
        _name="${_ans_n:-$_name}"
        read -r -p "  Email para commits [${_email:-}]: " _ans_e
        _email="${_ans_e:-$_email}"

        [[ -n "$_name" ]] && git config --global user.name "$_name"
        [[ -n "$_email" ]] && git config --global user.email "$_email"
        echo -e "${C_MARK_INST:-}  ✓ Git configurado.${R:-}"
        echo ""
    else
        echo -e "${C_MARK_INST:-}  ✓ Git já configurado (saindo: $(git config --global user.email 2>/dev/null))${R:-}"
        echo ""
    fi

    # Passo 2: SSH
    local _key
    _key="$(dotfiles_git_ssh_find_key)" || true
    if [[ -z "$_key" ]]; then
        echo -e "${B:-}[2/4] Gerar chave SSH${R:-}"
        echo "  Para conectar ao GitHub via SSH, precisa de uma chave."
        local _a2
        read -r -p "  Gerar chave ed25519 agora? (s/N): " _a2
        if dotfiles_menu_is_yes "$_a2"; then
            dotfiles_git_ssh_generate_key
        fi
        echo ""
    else
        echo -e "${C_MARK_INST:-}  ✓ Chave SSH encontrada${R:-}"
        echo ""
    fi

    # Passo 3: Testar SSH
    _key="$(dotfiles_git_ssh_find_key)" || true
    if [[ -n "$_key" ]]; then
        echo -e "${B:-}[3/4] Testar conexão SSH com GitHub${R:-}"
        local _a3
        read -r -p "  Testar agora? (S/n): " _a3
        if [[ -z "$_a3" ]] || dotfiles_menu_is_yes "$_a3"; then
            dotfiles_git_ssh_test_connection
        fi
        echo ""
    fi

    # Passo 4: GitHub CLI
    echo -e "${B:-}[4/4] GitHub CLI${R:-}"
    if ! command -v gh >/dev/null 2>&1; then
        echo "  gh CLI não está instalado."
        local _a4
        read -r -p "  Ver instruções de instalação? (s/N): " _a4
        if dotfiles_menu_is_yes "$_a4"; then
            echo ""
            echo "  Instalação (sudo):"
            echo "    curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg"
            echo "    echo 'deb [signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main' | sudo tee /etc/apt/sources.list.d/github-cli.list"
            echo "    sudo apt update && sudo apt install gh"
        fi
    else
        if gh auth status &>/dev/null; then
            echo -e "${C_MARK_INST:-}  ✓ gh instalado e autenticado.${R:-}"
        else
            echo "  gh instalado, mas não autenticado."
            local _a4
            read -r -p "  Autenticar agora? (s/N): " _a4
            if dotfiles_menu_is_yes "$_a4"; then
                gh auth login
            fi
        fi
    fi

    echo ""
    echo -e "${C_MARK_INST:-}✅ Setup concluído!${R:-}"
}

# ─── Dashboard (resumo exibido na entrada do submenu) ─────────────────────

dotfiles_git_dashboard() {
    local _r=${R:-} _path=${C_FILE_PATH:-} _green=${C_MARK_INST:-} _yellow=${C_MARK_NONE:-}
    local _name _email _ssh_status _gh_status _ssh_key _git_ver

    _name="$(git config --global user.name 2>/dev/null || echo '')"
    _email="$(git config --global user.email 2>/dev/null || echo '')"
    _git_ver="$(git --version 2>/dev/null | sed 's/git version //' || echo 'N/A')"

    _ssh_key="$(dotfiles_git_ssh_find_key)" || true
    if [[ -n "$_ssh_key" ]]; then
        _ssh_key="${_ssh_key##*/}"
        _ssh_status="${_green}✓ ${_ssh_key}${_r}"
    else
        _ssh_status="${_yellow}✗ (nenhuma chave)${_r}"
    fi

    _gh_status="$(dotfiles_git_gh_cached_status)"
    case "$_gh_status" in
        authed)        _gh_status="${_green}✓ autenticado${_r}" ;;
        unauthed)      _gh_status="${_yellow}✗ não autenticado${_r}" ;;
        not_installed) _gh_status="${_path}– não instalado${_r}" ;;
        *)             _gh_status="${_path}?${_r}" ;;
    esac

    echo ""
    echo -e "  Git:    ${_git_ver}"
    echo -e "  User:   ${_name}${_name:+ }<${_email}>"
    echo -e "  SSH:    ${_ssh_status}"
    echo -e "  gh:     ${_gh_status}"
    echo ""
}

# ─── Submenu ──────────────────────────────────────────────────────────────

dotfiles_git_submenu() {
    local choice

    while true; do
        dotfiles_git_dashboard

        echo "┌────────────────────────────────────────────┐"
        echo -e "│  ${B:-}Git / SSH / GitHub${R:-}                        │"
        echo "├────────────────────────────────────────────┤"
        echo "│                                            │"
        echo "│  1)  Git config (global)                   │"
        echo "│  2)  Chave SSH                             │"
        echo "│  3)  GitHub CLI (gh)                       │"
        echo "│  s)  Setup wizard (primeira vez)           │"
        echo "│  v)  Voltar                                │"
        echo "│                                            │"
        echo "└────────────────────────────────────────────┘"
        echo ""

        if dotfiles_git_setup_needed; then
            echo -e "${C_MARK_NONE:-}⚠ Setup recomendado. Digite 's' para iniciar.${R:-}"
            echo ""
        fi

        read -r -p "git> " choice || true
        echo ""

        case "${choice,,}" in
            v|voltar|q|quit|exit) break ;;
            1|config)   dotfiles_git_cmd_config ;;
            2|ssh)      dotfiles_git_cmd_ssh ;;
            3|gh)       dotfiles_git_cmd_gh ;;
            s|setup)    dotfiles_git_cmd_setup ;;
            "")
                continue
                ;;
            *)
                echo -e "${C_MARK_BLOCK:-}✖ Opção não reconhecida.${R:-}"
                echo "  Use número, 's' (setup) ou 'v' (voltar)."
                ;;
        esac

        if [[ "${choice,,}" != "v" && "${choice,,}" != "voltar" && \
              "${choice,,}" != "q" && "${choice,,}" != "quit" && \
              "${choice,,}" != "exit" ]]; then
            echo ""
            read -r -p "Pressione Enter para continuar..." || true
        fi
    done
}
