# dotfiles

Repositório de gerenciamento de dotfiles (arquivos de configuração) para Linux.

## Contexto Geral
- **Objetivo**: Centralizar configurações de sistema e aplicativos (Zsh, Git, VSCode, etc) em um único repositório e usar symlinks para aplicá-los na Home do usuário.
- **Mecanismo**: Usa scripts Bash para gerenciar a criação, remoção e auditoria de symlinks.

## Estrutura de Arquivos Críticos
- `data/`: Contém os arquivos originais. Qualquer alteração deve ser feita aqui.
- `data/.local/bin/ai-jail`: Script sandbox bubblewrap para AI agents — usa deny-lists para isolar secrets do host e isola state, config e data do OpenCode (porta 49380).
- `data/.local/bin/opencode`: Wrapper central do OpenCode — aplica `ai-jail` por padrão, aceita `--no-jail` para host direto e previne re-aninhar checando `$(hostname) == "ai-sandbox"`.
- `data/gitconfig`: Configurações globais do Git.
- `data/.config/autostart/`: Arquivos .desktop para inicialização automática de programas.
- `data/kde-plasma/`: Configurações do KDE Plasma — empacotadas juntas e traduzidas de forma invisível para `~/.config/` pelo gerenciador.
- `config/dotfile-names.list`: Arquivo texto simples contendo a lista de arquivos em `data/` que devem ser linkados.
- `config/agent-skills-bridge.list`: Escopo de bridagem de skills de IA (formato `<ferramenta>|<skill>`, `*` = todas as leaf skills).
- `config/opencode-profiles.list`: Perfis do OpenCode versionados (formato `<perfil>|<dest no perfil>|<fonte no repo>`) — segredos (`cli.json`, `service.json`, `auth.json`) e runtime (`node_modules`, `package*.json`) nunca entram.
- `scripts/dotfiles-lib.sh`: Biblioteca central com funções de manipulação de symlinks (`create_link`, `remove_link`, `check_link_status`).
- `scripts/install-agent-skills-bridge.sh`: Reconstrói os symlinks por-skill das ferramentas de IA (`claude|*`, `devin|*`, `antigravity|*`...) apontando para o acervo central `data/.agents/skills`. Idempotente; converte cópias idênticas em symlink com backup em `.bkp/`; pulsa dirs divergentes.
- `scripts/opencode-pf.sh`: CLI de perfis isolados do OpenCode (`create/list/show/run/clone/remove/doctor`) — `run` usa `XDG_DATA_HOME` por perfil + `--standalone` no fim dos args (aceita subcomandos como `run <nome> auth list`; exporta `OPENCODE_PROFILE` + `OPENCODE_PF_JAIL` — 1 jail / 0 `--no-jail` — para o badge do plugin TUI); `create --init/--with-auth` copiam do perfil padrão as credenciais (tabela `credential` do SQLite + `auth.json` legado — no v2 o auth vive no SQLite, não no auth.json). Substitui o `opencode-multi`, que não isola no opencode v2. Launcher instalado em `~/.local/bin/opencode-pf`.
- `scripts/install-opencode-profiles.sh`: Reconstrói os symlinks dos perfis OpenCode (`config/opencode-profiles.list`) para a fonte única; idempotente, com backup em `.bkp/`.
- `data/.config/opencode/plugins/profile-status/tui.tsx`: **Plugin CLI (TUI) do indicador de perfil** — lê `OPENCODE_PROFILE` (exportado por `opencode-pf run`) e renderiza `👤 <perfil>` no rodapé da home e junto ao prompt (slots `home.footer.status`/`prompt.footer.status`); sem `OPENCODE_PROFILE` (opencode puro) não renderiza nada. O estado do sandbox **não** é responsabilidade deste plugin: o ícone 🔐/🤞 e a leitura de `OPENCODE_PF_JAIL` foram movidos para o `jail-status` (que deriva o estado de hostname + `AI_EXECUTION_MODE` e por isso também cobre o opencode padrão). `OPENCODE_PF_JAIL` continua exportada pelo `opencode-pf` por compat, mas nada mais a consome. Descoberto via `<config-dir>/plugins/profile-status/tui.tsx` e espelhado por perfil pelo `install-opencode-profiles.sh` (sem tocar em `cli.json`).
- `data/.config/opencode/plugins/jail-status/tui.tsx`: **Plugin CLI (TUI) do indicador de jail** — deriva o modo de execução de DOIS sinais independentes: `os.hostname()` (fato do kernel — o UTS namespace só se chama `ai-sandbox` depois que o `bwrap` aplicou `--unshare-uts --hostname`) e `AI_EXECUTION_MODE` (intenção do launcher). Renderiza `🟢 jail` / `⚪ host` / `🔴` nos slots `home.footer.status`/`prompt.footer.status`, onde **a palavra é o FATO (kernel) e a cor é o ACORDO entre os dois sinais** — por isso o 🔴 ainda mostra onde o processo está de verdade. Clique no badge, ou o comando `/jail` na paleta (slash, sem LLM), abre dialog com o diagnóstico: regra do `AGENTS.md` aplicada, hostname, variável, se o `$HOME` é tmpfs (confirmação independente do jail, `ai-jail:295`), config-dir, socket do docker e PID. As regras de combinação são as do `data/.config/opencode/AGENTS.md`; `unset` conta como ausência de claim (não contradição) e, quando `declared == "jail"` sem jail real, o dialog avisa "trate como HOST" (a direção perigosa — abre inseguro). Plugin neutro: não conhece `opencode-pf`, então serve a jail, ao opencode padrão e a qualquer perfil. **A jail não precisa de nada para este plugin**: `ai-jail:205` já symlinka o dir `plugins` inteiro para `~/.config/opencode-jail/plugins`, então ele aparece lá automaticamente; as outras duas rotas exigem 1 linha cada (`dotfile-names.list` para o config padrão, `opencode-profiles.list` por perfil), ambas já existentes. Sem reatividade: o estado só muda com restart do opencode, então o badge lê os sinais a cada render — badge e dialog não podem divergir. A layer do keymap é montada por COMPONENTE dentro do slot do prompt (nunca no `setup()`, que roda fora do `Keymap.Provider`) — ver as armadilhas em `token-daily`.
- `data/.config/opencode/plugins/response-rule/index.ts`: **Plugin de servidor v2 do limite de respostas** — registra `ctx.session.hook("context")` e reescreve o system prompt para forçar "fewer than 8 lines" (EDITE as constantes no topo). Default export é um objeto literal `id`+`setup` **sem import de `@opencode/plugin`**: o servidor só resolve esse pacote com node_modules no config-dir (ausente no perfil), então o objeto literal satisfaz o schema do runtime. Substitui o antigo `plugin/response-rule.ts` (hook v1 `experimental.chat.system.transform`, quebrado no v2). Descoberto em `<config-dir>/plugins/response-rule/` e espelhado por perfil pelo `install-opencode-profiles.sh`.
- `data/.config/opencode/plugins/token-daily/tui.tsx`: **Plugin CLI (TUI) do contador diário de tokens** — escuta `message.updated` (+ timer de 30s como rede de segurança), soma apenas o DELTA novo por sessão (baseline persistido em `token-daily-seen`, evita double-count após restart) e acumula por dia (`YYYY-MM-DD`) em storage durável (`token-daily`). Renderiza nos slots `home.footer.status`/`prompt.footer.status`: `↑X ↓Y` sublinhado — clique (ou `/token-daily` na paleta) abre dialog centralizado com a **data do dia sozinha no topo** (`◀ Seg 22 Set (hoje) ▶` — ◀/▶ indicam navegação) e o breakdown do dia (input/output/reasoning/cache), que fica aberto até clicar fora; dentro do dialog, `←`/`→` navegam entre os dias com uso registrado (layer `mode:"modal"` + `enabled`, sem roubar `left`/`right` do cursor do prompt). Espelhado por perfil via `install-opencode-profiles.sh` e linkado no config padrão via `dotfile-names.list` (apenas `token-daily`, sem response-rule, para não mudar o comportamento do opencode padrão).
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
