---
tags: [dotfiles, versionamento, kde-plasma, arquitetura, stow]
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

