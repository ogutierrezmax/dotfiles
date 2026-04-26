---
name: dotfiles-config-integrator
description: "Integra as configurações de um programa ao repositório de dotfiles: move arquivos para data/, cria symlinks, atualiza dotfile-names.list, atualiza .gitignore para arquivos sensíveis e verifica que tudo funciona. Usa as APIs existentes do repositório (dotfiles-lib.sh, dotfiles-menu.sh). Use quando o dotfiles-config-researcher já gerou o relatório e o llm-config-guardian já auditou os arquivos, e agora é hora de efetivamente mover e integrar os configs ao repo."
---

# Dotfiles Config Integrator

Executa a integração técnica de um programa no repositório de dotfiles. Esta skill pressupõe que o `dotfiles-config-researcher` já mapeou os arquivos e o `llm-config-guardian` já auditou a segurança. Ela trabalha com dados concretos — não pesquisa nem audita.

## Quando usar

- Após o `dotfiles-config-researcher` ter gerado o relatório de configuração
- Após o `llm-config-guardian` ter auditado os arquivos públicos
- Quando é hora de efetivamente mover os configs para o repositório

## Conhecimento obrigatório sobre o repositório

Antes de executar qualquer operação, você DEVE entender a estrutura:

### Estrutura do repo
```
dotfiles/
├── data/              ← Fonte da verdade: arquivos reais ficam aqui
├── config/
│   └── dotfile-names.list  ← Lista de arquivos a linkar (um por linha)
├── scripts/
│   ├── dotfiles-lib.sh     ← Funções core (NÃO reinvente, USE estas)
│   └── install-dotfiles.sh ← Instalação batch
├── .gitignore              ← Padrões de exclusão
└── dotfiles-menu.sh        ← Menu interativo com comando `add`
```

### Como `dotfile-names.list` funciona
- Uma entrada por linha, relativa a `data/`
- Sem ponto no nome → o symlink em `~` ganha ponto (ex: `gitconfig` → `~/.gitconfig`)
- Com ponto no nome → o symlink em `~` mantém o nome (ex: `.zshrc` → `~/.zshrc`)
- Paths com `/` são suportados (ex: `.config/Cursor/User/settings.json`)
- Linhas com `#` são comentários
- Linhas vazias são ignoradas

### Estados possíveis de um arquivo (da `dotfiles-lib.sh`)
- `importable`: existe em `~` mas não em `data/` — pode ser importado
- `not_installed`: existe em `data/` mas sem symlink em `~`
- `installed`: symlink correto em `~` apontando para `data/`
- `blocking_file`: arquivo real em `~` impedindo o symlink
- `wrong_target`: symlink em `~` aponta para lugar errado
- `unavailable`: não existe em `data/` nem em `~`

## Processo

### 1. Verificar estado atual

Antes de qualquer ação, verifique o que já existe:

```bash
# Verificar se o programa já tem arquivos em data/
ls -la data/.config/programa/ 2>/dev/null || ls -la data/programa* 2>/dev/null

# Verificar se já está na lista
grep "programa" config/dotfile-names.list

# Verificar estado dos symlinks
# (usar dotfiles_status_for_file internamente se possível)
```

Se o programa já está parcialmente integrado, ajuste os passos (não duplique).

### 2. Mover arquivos públicos para `data/`

Para cada arquivo classificado como **público** pelo `dotfiles-config-researcher`:

**Se o arquivo usa path XDG (`~/.config/programa/`):**
```bash
# Criar estrutura de diretórios em data/
mkdir -p data/.config/programa/

# Mover o arquivo
mv ~/.config/programa/config.toml data/.config/programa/config.toml
```

**Se o arquivo usa path tradicional (`~/.programarc`):**
```bash
# Mover diretamente (sem ponto no nome em data/ → ganha ponto no symlink)
mv ~/.programarc data/programarc
# OU com ponto se preferir manter consistência:
mv ~/.programarc data/.programarc
```

**Para diretórios inteiros:**
```bash
# Mover o diretório todo
mv ~/.config/programa data/.config/programa
```

### 3. Criar symlinks

Use a função existente do repositório quando possível. Se executando manualmente:

```bash
# O ln -sf cria o link forçando (substitui se já existir)
ln -sf "$(pwd)/data/.config/programa" ~/.config/programa
```

O ideal é usar o menu: `./dotfiles-menu.sh` → selecionar o número do arquivo → ele cria o symlink automaticamente.

### 4. Atualizar `config/dotfile-names.list`

Adicione as novas entradas ao arquivo. Agrupe sob um comentário com o nome do programa:

```bash
# Formato: adicionar ao final do arquivo
echo "" >> config/dotfile-names.list
echo "# [Nome do programa]" >> config/dotfile-names.list
echo ".config/programa/config.toml" >> config/dotfile-names.list
```

**Regras para os nomes:**
- Use o path relativo a `data/`
- Se o arquivo original em `~` começa com ponto, mantenha o ponto em `data/` e na lista
- Se o arquivo NÃO começa com ponto, NÃO adicione ponto (a `dotfiles-lib.sh` adiciona automaticamente)

### 5. Atualizar `.gitignore` (para arquivos sensíveis)

Para cada arquivo classificado como **sensível** pelo `dotfiles-config-researcher`, adicione um padrão ao `.gitignore`:

```bash
# Adicionar ao .gitignore na seção apropriada
# Use comentário para identificar o programa

# [Programa] — arquivos sensíveis
data/.config/programa/credentials.json
data/.config/programa/secrets*
```

**Para arquivos gerados** (cache, histórico), eles não são movidos para `data/`, então não precisam de `.gitignore` — eles simplesmente não são incluídos.

### 6. Tratar arquivos sensíveis

Para cada arquivo sensível, crie uma versão `.example`:

```bash
# Copiar o sensível, remover os valores
cp ~/.config/programa/credentials.json data/.config/programa/credentials.json.example
# Editar o .example para remover valores reais, deixando apenas as chaves
```

Se o programa suporta, configure o padrão `.local`:
```bash
# No config principal, adicionar referência ao arquivo local
# Exemplo para shell configs:
# [ -f ~/.config/programa/local.conf ] && source ~/.config/programa/local.conf
```

### 7. Verificação final

Após todas as operações, verifique:

```bash
# Symlinks funcionam?
ls -la ~/.config/programa/   # Deve mostrar -> /caminho/para/dotfiles/data/.config/programa/

# O programa funciona com os symlinks?
# (executar o programa e verificar que carrega as configs)

# A lista está correta?
cat config/dotfile-names.list | grep programa
```

## Regras

- **NUNCA reinvente funções que já existem** em `dotfiles-lib.sh` — use as APIs do repo
- **SEMPRE verifique o estado atual** antes de mover/linkar — evite sobrescrever
- **SEMPRE faça backup** se um arquivo real em `~` vai ser substituído por symlink (o menu já faz isso via `.bkp/`)
- **NUNCA adicione arquivos sensíveis a `data/`** sem antes ter o padrão no `.gitignore`
- **Agrupe as entradas** em `dotfile-names.list` com um comentário do programa
- **Teste os symlinks** — um link quebrado é pior que não ter link
