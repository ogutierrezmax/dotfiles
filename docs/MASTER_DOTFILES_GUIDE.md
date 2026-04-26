# Guia Mestre de Dotfiles 🚀

Este documento é a base de conhecimento central para a criação, manutenção e evolução de um sistema de dotfiles profissional. Ele consolida práticas de mercado, estratégias de organização e segurança para garantir um ambiente de desenvolvimento reprodutível e eficiente.

---

## 1. Fundamentos e Filosofia

### O que são Dotfiles?
Arquivos cujos nomes começam com um ponto (`.`), geralmente ocultos, usados para configurar o comportamento de aplicações no Unix/Linux (ex: `.zshrc`, `.gitconfig`, `.vimrc`).

### Por que versionar?
- **Reprodutibilidade**: Configure uma máquina nova em minutos.
- **Portabilidade**: Leve suas ferramentas e atalhos para qualquer lugar.
- **Histórico**: Acompanhe a evolução da sua produtividade e desfaça erros facilmente.

### XDG Base Directory Specification
Uma prática moderna é evitar poluir a raiz da sua `$HOME`. Sempre que possível, configure suas aplicações para usar:
- `XDG_CONFIG_HOME`: `~/.config` (Configurações)
- `XDG_DATA_HOME`: `~/.local/share` (Dados de usuário)
- `XDG_CACHE_HOME`: `~/.cache` (Arquivos temporários)

---

## 2. Estratégias de Organização

### Modular vs Monolítico
- **Monolítico**: Um único arquivo gigante (difícil de manter).
- **Modular (Recomendado)**: Divisão por aplicação ou funcionalidade.
  ```text
  dotfiles/
  ├── zsh/
  │   ├── aliases.zsh
  │   ├── env.zsh
  │   └── functions.zsh
  ├── nvim/
  ├── git/
  └── scripts/
  ```

### Carregamento Dinâmico
No seu arquivo principal (ex: `.zshrc`), use um loop para carregar os módulos:
```bash
for file in ~/.zshrc.d/*.zsh; do
  [ -r "$file" ] && source "$file"
done
```

---

## 3. Ferramentas de Gerenciamento

| Ferramenta | Estilo | Recomendação |
| :--- | :--- | :--- |
| **Scripts Customizados** | Manual/Bash | Ótimo para aprendizado e controle total (como este repositório). |
| **GNU Stow** | Symlinks | O padrão da indústria para simplicidade. Cria "fazendas de links". |
| **Chezmoi** | Templating | Para quem gerencia múltiplas máquinas (Mac/Linux/Windows) com segredos. |
| **Dotbot** | YAML/Bootstrap | Focado em automação de instalação inicial. |

---

## 4. Segurança e Gerenciamento de Segredos

**REGRA DE OURO: NUNCA submeta segredos ao Git.**

### Estratégias de Proteção:
1. **O Padrão `.local`**:
   No final do seu arquivo, adicione:
   ```bash
   [ -f ~/.zshrc.local ] && source ~/.zshrc.local
   ```
   Adicione `*.local` ao seu `.gitignore`.
2. **Variáveis de Exemplo**:
   Mantenha um `.env.example` com as chaves necessárias, mas sem os valores.
3. **Gerenciadores de Senhas CLI**:
   Use `op` (1Password) ou `bw` (Bitwarden) para injetar segredos dinamicamente:
   ```bash
   export GITHUB_TOKEN=$(op read "op://Private/GitHub/credential")
   ```

---

## 5. Automação e Bootstrapping (O Script `install.sh`)

Um bom script de instalação deve ser **Idempotente** (pode ser rodado várias vezes sem quebrar nada).

### Checklist de Bootstrapping:
- [ ] **Detectar SO**: `uname` para distinguir Linux de macOS.
- [ ] **Instalar Gerenciador de Pacotes**: (Homebrew, Apt, Pacman).
- [ ] **Instalar Dependências**: (Git, Zsh, Neovim).
- [ ] **Criar Symlinks**: Use `ln -sf` para garantir que o link seja criado/atualizado.
- [ ] **Configurar Shell Padrão**: `chsh -s $(which zsh)`.

---

## 6. Performance: O Terminal Veloz

O terminal deve abrir instantaneamente (< 100ms).

- **Lazy Loading**: Ferramentas como `nvm`, `rvm` ou `sdkman` são lentas. Use plugins de "lazy load" que só carregam a ferramenta quando você digita o comando (ex: `node`).
- **Evite Subshells**: Minimiza chamadas a `$(...)` no startup. Prefira constantes.
- **Built-ins**: Use funcionalidades nativas do shell sempre que possível em vez de chamar binários externos como `sed` ou `awk`.

---

## 7. Fluxo de Trabalho e Melhores Práticas

- **Commits Semânticos**: Use `feat:`, `fix:`, `refactor:` para suas configurações.
- **Documentação**: Mantenha um `README.md` que explique como instalar em uma máquina virgem.
- **Branches por Máquina**: Se as máquinas forem muito diferentes, use branches (embora o uso de condicionais de SO no mesmo arquivo seja preferível).
- **Validação**: Use `shellcheck` para garantir que seus scripts não tenham bugs ocultos.

---

## 8. Stack Moderna Recomendada (2025/2026)

- **Shell**: Zsh (com Oh My Zsh ou Zap) ou Fish.
- **Editor**: Neovim (configurado com Lua).
- **Multiplexador**: Tmux (com `tpm` para plugins).
- **Prompt**: Starship (rápido e cross-shell).
- **Terminal**: Alacritty, Kitty ou WezTerm (aceleração por GPU).
- **Utilidades CLI**: `fzf` (busca), `ripgrep` (grep rápido), `fd` (find rápido), `zoxide` (cd inteligente).
