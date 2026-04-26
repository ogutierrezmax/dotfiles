---
name: dotfiles-config-researcher
description: "Pesquisa e mapeia todos os arquivos de configuração de um programa antes de adicioná-lo ao repositório de dotfiles. Identifica localização dos configs, classifica cada arquivo (público/sensível/gerado), detecta dependências (plugin managers, temas) e levanta boas práticas de versionamento. Use quando o usuário quiser adicionar um programa novo ao dotfiles, versionar configs de uma ferramenta, ou quando precisar saber onde um programa guarda suas configurações, quais são sensíveis e como versioná-las corretamente."
---

# Config Researcher

Antes de versionar as configurações de qualquer programa, é preciso entender sua paisagem de configuração completa. Esta skill faz esse trabalho de inteligência — pesquisando online e no sistema local — para que as etapas seguintes (auditoria, onboarding, documentação) tenham dados sólidos.

## Quando usar

- O usuário quer adicionar um programa novo ao repositório de dotfiles
- O usuário não sabe onde um programa guarda seus configs
- O usuário quer saber se um programa tem variáveis sensíveis
- Antes de qualquer operação de `dotfiles-onboarding`

## Processo

### 1. Pesquisa online

Use `search_web` e `read_url_content` para pesquisar:

- Documentação oficial do programa sobre arquivos de configuração
- Wiki do Arch Linux (fonte excelente para paths de config no Linux)
- Issues e discussões sobre versionamento de configs desse programa

**Informações a extrair:**
- Path(s) principal(is) de configuração
- Se o programa segue o padrão XDG Base Directory (`~/.config/programa/`)
- Se o programa gera arquivos que NÃO devem ser versionados (cache, state, histórico)
- Se há variáveis de ambiente que controlam paths de config
- Se há um plugin manager ou sistema de extensões
- Boas práticas específicas da comunidade para versionar esse programa

### 2. Inspeção do sistema local

Use `run_command` para verificar o que existe na máquina do usuário:

```bash
# Buscar por configs no home do usuário
find ~ -maxdepth 3 -name "*programa*" -not -path "*/node_modules/*" -not -path "*/.cache/*" 2>/dev/null

# Verificar paths XDG
ls -la ~/.config/programa/ 2>/dev/null

# Verificar paths tradicionais
ls -la ~/.programarc ~/.programa.conf ~/.programa/ 2>/dev/null

# Verificar se já existe algo no repo
ls -la "$(pwd)/data/"*programa* 2>/dev/null
```

### 3. Classificar cada arquivo encontrado

Para CADA arquivo ou diretório de configuração, classifique em uma das 3 categorias:

| Categoria | Critério | Ação no dotfiles |
|-----------|----------|------------------|
| **público** | Não contém segredos, é reproduzível, representa preferências do usuário | ✅ Versionar em `data/` |
| **sensível** | Contém API keys, tokens, senhas, paths privados, credenciais | ❌ NÃO versionar. Criar `.local` ou `.example` |
| **gerado** | Cache, histórico, state, compilados, locks, diretórios de plugins instalados | ❌ Ignorar completamente |

**Para classificar corretamente**, leia o conteúdo do arquivo quando possível:

```bash
# Ver conteúdo de arquivos de config (não binários, <50KB)
cat ~/.config/programa/config.toml
```

Procure por padrões como:
- `api_key`, `token`, `secret`, `password`, `credential` → **sensível**
- `cache`, `history`, `state`, `lock`, `*.compiled` → **gerado**
- Temas, keybindings, preferências visuais, atalhos → **público**

### 4. Identificar dependências

Para cada programa, verifique:

- **Plugin manager**: O programa usa um gerenciador de plugins? (ex: TPM para tmux, vim-plug para vim, oh-my-zsh para zsh)
  - Se sim: o plugin manager precisa ser instalado separadamente na restauração
  - Os plugins instalados geralmente são **gerados** (reinstalados pelo manager), mas a **lista de plugins** no config é **pública**
- **Temas**: Há temas instalados manualmente? Onde ficam?
- **Extensões**: Há extensões que precisam de setup adicional?

### 5. Gerar relatório

A saída desta skill é um relatório estruturado em markdown. Use **exatamente** este formato:

```markdown
## 📋 Relatório de Configuração: [nome do programa]

### Informações gerais
- **Programa**: [nome e versão se relevante]
- **Segue XDG**: sim / não / parcial
- **Path principal**: [caminho]
- **Plugin manager**: [nome] ou nenhum
- **Documentação consultada**: [links]

### Arquivos encontrados

| Arquivo/Diretório | Categoria | Justificativa |
|-------------------|-----------|---------------|
| `~/.config/programa/config.toml` | público | Preferências e keybindings |
| `~/.config/programa/credentials.json` | sensível | Contém tokens de API |
| `~/.config/programa/cache/` | gerado | Cache reconstruído automaticamente |

### Dependências para restauração
- [x] Instalar o programa: `sudo apt install programa`
- [x] Instalar plugin manager: `git clone ... ~/.programa/plugins/manager`
- [ ] Plugins são instalados automaticamente pelo manager

### Boas práticas identificadas
- [práticas específicas encontradas na pesquisa]

### Recomendações para o .gitignore
- `programa-history` (arquivo de histórico, gerado)
- `programa-credentials*` (arquivo sensível)
```

## Regras

- **Sempre pesquise online primeiro** — não assuma que sabe onde o programa guarda configs
- **Sempre verifique localmente depois** — o sistema pode ter configs em paths não-padrão
- **Na dúvida, classifique como sensível** — é melhor ser conservador
- **Não modifique nenhum arquivo** — esta skill é apenas de leitura e pesquisa
- **Não pule a pesquisa online** — mesmo para programas conhecidos, as boas práticas podem ter mudado
