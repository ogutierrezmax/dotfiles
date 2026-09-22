---
tags: [dotfiles, versionamento, kde-plasma, arquitetura, stow, isolamento, daemon, cli]
type: concept
---

# Padrões de Gerenciamento de Dotfiles

## 1. Empacotamento Lógico (Estilo GNU Stow)
**Contexto**: Em repositórios de dotfiles que usam espelhamento direto de caminhos (`data/caminho` → `~/caminho`), arquivos de naturezas diferentes acabam misturados na raiz de diretórios comuns (como `.config/`).
**Solução Abstraída**: Adotar "pacotes" (pastas agrupadoras). Ao criar o link simbólico, a lógica remove o diretório do pacote (o nível raiz dentro do diretório de dados) antes de compor o caminho no diretório home.
**Implementação Sistêmica**:
- Se o arquivo for `data/<pacote>/<caminho_real>`, o atalho é criado em `~/<caminho_real>`.
- Isso previne a criação de pastas artificiais (ex: `~/<pacote>/`) no ambiente final e mantém a flexibilidade modular.

## 2. Versionamento Cauteloso de Ambientes Desktop (ex: KDE Plasma)
**Contexto**: Ambientes gráficos modernos (como KDE Plasma ou GNOME) espalham configurações por centenas de arquivos INI. Grande parte desses arquivos contêm estado de sessão, geometria de janelas específicas de hardware ou cache, que causam conflitos se versionados diretamente.
**Solução Abstraída**: Nunca realize o tracking do diretório raiz de configuração gráfica inteiro (`~/.config/` ou similar).
**Princípios**:
1. **Seleção Cirúrgica**: Escolha versionar ativamente apenas arquivos contendo preferências do usuário. Para o KDE, isso inclui:
   - Cores e tema (`kdeglobals`)
   - Comportamento de janela (`kwinrc`, `kwinrulesrc`)
   - Atalhos (`kglobalshortcutsrc`)
   - Disposição visual de interface (`plasmashellrc`, `plasma-org.kde.plasma.desktop-appletsrc`)
2. **Segregação**: Agrupe esses arquivos em um pacote dedicado (ex: `kde-plasma/`) para evitar poluição visual e facilitar o rollback de todo o ambiente sem afetar outros programas.

## 3. Inicialização Automática e Segurança (Autostart)
**Contexto**: Arquivos de autostart (`.desktop`) são vetores de execução de código que frequentemente contêm caminhos absolutos ou argumentos de comando sensíveis. Por serem texto puro, são inseguros para armazenar credenciais.
**Solução Abstraída**: Versionar arquivos `.desktop` individualmente em `data/.config/autostart/` e aplicar guardrails de documentação inline.
**Princípios**:
1. **Guardrails Proativos**: Inserir comentários `SECURITY NOTE` no topo de arquivos que podem ser alvo de injeção de segredos por LLMs.
2. **Abstração de Caminhos**: Preferir comandos que usem o `$PATH` ou variáveis de ambiente em vez de caminhos absolutos para o `Exec=`, garantindo portabilidade entre máquinas com nomes de usuário diferentes.
3. **Bloqueio de Commits Inseguros**: Implementar hooks de pré-commit (`pre-commit`) que escaneiam o diff em busca de padrões de segredos (API keys, tokens) antes de permitir a persistência no repositório.

## 4. Versionamento de Scripts Customizados (~/.local/bin/)
**Contexto**: Scripts em `~/.local/bin/` são executáveis do usuário (padrão XDG) e frequentemente precisam ser versionados para replicar ambiente entre máquinas. Diferente de arquivos de config, scripts são código executável e têm riscos específicos.
**Solução Abstraída**: Armazenar scripts em `data/.local/bin/` no repositório, com entrada em `dotfile-names.list` como `.local/bin/script-name`. O symlink é criado de `~/.local/bin/script-name` → `data/.local/bin/script-name`.
**Princípios**:
1. **Auditoria Obrigatória**: Scripts versionados devem passar pelo `llm-config-guardian` para adicionar guardrails inline (SECURITY NOTE, DANGER ZONE) nos pontos de risco.
2. **Pontos de Risco em Scripts**: Avaliar especificamente: eval de código externo, source de arquivos não-versionados, parsing de args do usuário, montagens de sistema (Docker socket, GPU, etc.).
3. **Symlinks e Partições Read-Only**: Se `~/.local` estiver montado como read-only (ex.: para segurança), o symlink não pode ser gerenciado pelo install-dotfiles.sh — usuário deve criar manualmente remontando como rw, criando o link e remontando como ro.
4. **Dependências Explicitas**: Documentar dependências externas (ex: bubblewrap) que o script requer, pois não estão no repositório.

## 5. Sandbox Scripts para AI Agents
**Contexto**: Scripts que usam bubblewrap para isolar AI coding agents (Claude Code, OpenCode, etc.) têm um perfil de risco elevado porque definem a boundary de segurança entre o agente e os dados do host.
**Solução Abstraída**: Versionar o script com guardrails DANGER ZONE em cada ponto crítico: deny-lists (definem o que o agente NÃO vê), eval de runtimes (mise, nvm), montagens de dispositivos (Docker socket, GPU), e parsing de args.
**Princípios**:
1. **Deny-lists como Boundary**: As listas de diretórios negados (DOTDIR_DENY, CONFIG_DENY, CACHE_DENY) são a fronteira de segurança — alterações nelas impactam diretamente a exposição de secrets. Devem ter DANGER ZONE.
2. **tmpfs $HOME**: Montar `$HOME` como tmpfs e fazer bind seletivo de dotdirs é mais seguro que montar `$HOME` real e esconder subdiretórios.
3. **Docker Socket**: Expor `/var/run/docker.sock` dá ao agente controle total do Docker host — documentar com SECURITY NOTE.
4. **Runtimes Externos**: Mise, NVM e similares executam código dentro do sandbox — se o runtime estiver comprometido, o sandbox não protege.

## 6. Isolamento por Perfil em CLIs com Background Service
**Contexto**: Wrappers que encapsulam CLIs com "perfis" (config/auth/estado por perfil) quebram quando o CLI subjacente migra de arquitetura processo-único para um **background service compartilhado**. O wrapper exporta o env do perfil no cliente, mas quem executa de verdade (o daemon) nasceu antes, com o env original — os perfis ficam **inertes** e compartilham conta/estado entre si.
**Solução Abstraída**: O isolamento só é real se o **servidor privado nascer com o env do perfil**:
1. **Env no processo real**: todas as variáveis de redirecionamento (config dir, data dir) devem ser exportadas antes do `exec` do processo que vai executar; quando há daemon, o cliente deve iniciar servidor próprio (flag tipo `--standalone`) em vez de conectar no serviço compartilhado — senão nada do env chega a quem roda.
2. **Data dir por instância**: o diretório de dados apontado pelo perfil deve ser o **nível da instância** (`<root>/<perfil>/…`), nunca o pai — o pai vira área comum entre todos os perfis.
3. **Verificação de lugar**: para validar "tem config/auth?", conferir o caminho que o app resolve de verdade (ex.: `opencode debug paths`), não o lugar que o wrapper "acha" que deve ser — o caminho resolvido muda entre versões do app.
4. **Espelhamento por fonte única**: perfis que espelham a config normal devem usar symlinks para os MESMOS arquivos versionados — sem duplicar cópias que divergem com o tempo.
**Princípios**:
- Wrapper bash próprio (paridade de features + correções) > fork de projeto em outra linguagem > plugin no processo (plugin roda tarde demais para redirecionar startup).
- Arquivos de credencial (`auth.json`, `cli.json`, `service.json`) nunca versionar; preservá-los locais e por perfil.
- Remoção/cópia de perfis: confirmação explícita do usuário antes de `rm`; `clone` não propaga credenciais nem banco de sessões (login novo via `/connect`).
- Diagnóstico (`doctor`) deve alertar sobre daemon compartilhado ativo e resíduos de execução antiga — sintomas de env quebrado são confundíveis com bug do usuário.

