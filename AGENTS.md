# dotfiles

Repositório de gerenciamento de dotfiles (arquivos de configuração) para Linux.

## Contexto Geral
- **Objetivo**: Centralizar configurações de sistema e aplicativos (Zsh, Git, VSCode, etc) em um único repositório e usar symlinks para aplicá-los na Home do usuário.
- **Mecanismo**: Usa scripts Bash para gerenciar a criação, remoção e auditoria de symlinks.

## Estrutura de Arquivos Críticos
- `data/`: Contém os arquivos originais. Qualquer alteração deve ser feita aqui.
- `data/.local/bin/ai-jail`: Script sandbox bubblewrap para AI agents — usa deny-lists para isolar secrets do host.
- `data/gitconfig`: Configurações globais do Git.
- `data/.config/autostart/`: Arquivos .desktop para inicialização automática de programas.
- `data/kde-plasma/`: Configurações do KDE Plasma — empacotadas juntas e traduzidas de forma invisível para `~/.config/` pelo gerenciador.
- `config/dotfile-names.list`: Arquivo texto simples contendo a lista de arquivos em `data/` que devem ser linkados.
- `config/agent-skills-bridge.list`: Escopo de bridagem de skills de IA (formato `<ferramenta>|<skill>`, `*` = todas as leaf skills).
- `config/opencode-profiles.list`: Perfis do OpenCode versionados (formato `<perfil>|<dest no perfil>|<fonte no repo>`) — segredos (`cli.json`, `service.json`, `auth.json`) e runtime (`node_modules`, `package*.json`) nunca entram.
- `scripts/dotfiles-lib.sh`: Biblioteca central com funções de manipulação de symlinks (`create_link`, `remove_link`, `check_link_status`).
- `scripts/install-agent-skills-bridge.sh`: Reconstrói os symlinks por-skill das ferramentas de IA (`claude|*`, `devin|*`, `antigravity|*`...) apontando para o acervo central `data/.agents/skills`. Idempotente; converte cópias idênticas em symlink com backup em `.bkp/`; pulsa dirs divergentes.
- `scripts/opencode-pf.sh`: CLI de perfis isolados do OpenCode (`create/list/show/run/clone/remove/doctor`) — `run` usa `XDG_DATA_HOME` por perfil + `--standalone` no fim dos args (aceita subcomandos como `run <nome> auth list`); `create --init/--with-auth` copiam do perfil padrão as credenciais (tabela `credential` do SQLite + `auth.json` legado — no v2 o auth vive no SQLite, não no auth.json). Substitui o `opencode-multi`, que não isola no opencode v2. Launcher instalado em `~/.local/bin/opencode-pf`.
- `scripts/install-opencode-profiles.sh`: Reconstrói os symlinks dos perfis OpenCode (`config/opencode-profiles.list`) para a fonte única; idempotente, com backup em `.bkp/`.
- `data/.config/opencode/plugins/profile-status/tui.tsx`: **Plugin CLI (TUI) do indicador de perfil** — lê `OPENCODE_PROFILE` (exportado por `opencode-pf run`) e renderiza `🔐 <perfil>` no rodapé da home e junto ao prompt (slots `home.footer.status`/`prompt.footer.status`); descoberto via `<config-dir>/plugins/profile-status/tui.tsx` e espelhado por perfil pelo `install-opencode-profiles.sh` (sem tocar em `cli.json`).
- `dotfiles-menu.sh`: Script principal de interface (TUI) para o usuário. Comando `skills` roda o bridge; comando `profiles` roda o instalador de perfis OpenCode.

## Programas Gerenciados
- **WezTerm**: `data/wezterm.lua` — terminal GPU-accelerated configurado via Lua (substituiu Konsole).
- **Tmux**: `data/.tmux.conf` — multiplexador de terminal com persistência de sessão.
- **KDE Plasma**: `data/kde-plasma/` — configurações do ambiente desktop agrupadas como pacote.

## Fluxos para Agentes de IA
- **Para adicionar novo arquivo**:
    1. Colocar o arquivo em `data/`.
    2. Adicionar o nome do arquivo em `config/dotfile-names.list`.
    3. (Opcional) Executar `scripts/install-dotfiles.sh` para linkar.
- **Convenções de Código**:
    - Scripts Bash seguem `ShellCheck`.
    - Commits devem ser **atômicos**: uma ferramenta ou mudança lógica por commit.
    - Documentação técnica detalhada em `docs/` (ex: `docs/tmux.md`).

## Guia de Desenvolvimento
- Scripts principais estão em `scripts/`.
- Use a `dotfiles-lib.sh` para qualquer operação de sistema para garantir consistência.
