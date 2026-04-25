# Oh My Zsh: Versionando Plugins e Customizações

Este guia ensina **como versionar corretamente o Oh My Zsh no repositório dotfiles** — o que vai no Git, o que é instalado por script, e como a pasta `$ZSH_CUSTOM` é a peça central dessa estratégia.

> **Pré-requisito:** Leia o guia de fundamentos do Zsh antes deste.
> → [Zsh: Versionando no Dotfiles](../zsh/README.md)

---

## 1. O que é Oh My Zsh e o que NÃO deve ser versionado

Oh My Zsh (OMZ) é um **framework** que roda sobre o Zsh. Ele não substitui o Zsh — ele o complementa, fornecendo:

- Um sistema de **plugins** para carregar funcionalidades com uma linha no `.zshrc`
- Um sistema de **temas** para personalizar o prompt
- A variável `$ZSH_CUSTOM`, uma pasta que o OMZ carrega automaticamente

**O OMZ em si é uma dependência externa.** Assim como o `node_modules` não vai para o Git, a pasta `~/.oh-my-zsh/` também não vai:

| O que é | Versionar? | Como chega na máquina |
|---|---|---|
| `~/.oh-my-zsh/` (o framework) | ❌ Não | Script de instalação |
| `~/.oh-my-zsh/custom/plugins/zsh-autosuggestions/` | ❌ Não | Script de instalação |
| `~/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting/` | ❌ Não | Script de instalação |
| `~/.oh-my-zsh/custom/aliases.zsh` | ✅ Sim | Symlink ou cópia do dotfiles |
| `data/.zshrc` (lista de plugins) | ✅ Sim | Symlink do dotfiles |

A regra é simples: **código de terceiros não vai para o dotfiles — apenas a sua configuração vai.**

---

## 2. Instalação do OMZ (dependência, não versionada)

Em uma máquina nova, instale o OMZ antes de criar os symlinks:

```bash
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
```

Após a instalação, o OMZ cria um `~/.zshrc` padrão. **Substitua-o pelo symlink do dotfiles:**

```bash
rm ~/.zshrc
ln -sf ~/dotfiles/data/.zshrc ~/.zshrc
```

---

## 3. Plugins Externos: Instalar, Não Versionar

Plugins externos como `zsh-autosuggestions` e `zsh-syntax-highlighting` precisam ser **clonados** em `$ZSH_CUSTOM/plugins/`. Eles **não entram no repositório** — são dependências instaladas por script.

### Por que não commitar o código dos plugins?

- O código de plugin tem dezenas/centenas de arquivos — polui o repositório
- Você não mantém esse código — é upstream de terceiros
- Em uma máquina nova, `git clone` já traz o que você precisa (seus arquivos), e um script instala as dependências

### Como instalar os plugins externos

```bash
# Execute uma vez por máquina (ou coloque em um script de bootstrap)
git clone https://github.com/zsh-users/zsh-autosuggestions \
  ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions

git clone https://github.com/zsh-users/zsh-syntax-highlighting \
  ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting
```

### Como declarar os plugins no `.zshrc` (este arquivo É versionado)

```bash
# data/.zshrc — apenas o nome do plugin; o código já deve estar instalado
plugins=(git zsh-autosuggestions zsh-syntax-highlighting)
```

> **Atenção:** listar um plugin aqui sem ter clonado o repositório dele resulta em erro de "plugin not found". A declaração no `.zshrc` e a instalação física são coisas separadas.

### Plugins recomendados para o dia a dia

| Plugin | O que faz | Por que usar |
|---|---|---|
| `git` | Aliases curtos para Git (`gst`, `gco`, `gl`...) | Economiza tempo em operações cotidianas |
| `zsh-autosuggestions` | Sugere comandos do histórico enquanto você digita | Reduz retrabalho de forma visual |
| `zsh-syntax-highlighting` | Coloriza o comando: verde se válido, vermelho se inválido | Pega erros de digitação antes do Enter |

> **Regra de ouro:** comece com 2–3 plugins. É muito mais fácil adicionar depois do que diagnosticar lentidão.

---

## 4. `$ZSH_CUSTOM`: A Pasta que Você Versiona

A variável `$ZSH_CUSTOM` aponta por padrão para `~/.oh-my-zsh/custom/`. **O OMZ carrega automaticamente todo arquivo `.zsh` dentro dessa pasta** — sem nenhum `source` manual.

Essa pasta é onde você coloca **suas customizações**: aliases, funções, variáveis de ambiente. Diferente dos plugins, **esses arquivos são seus e devem ser versionados**.

### Estratégia: versionar os arquivos e linkar a pasta

A abordagem mais limpa é versionar seus arquivos `.zsh` no repositório e apontar `$ZSH_CUSTOM` para o dotfiles:

```bash
# Opção A: apontar $ZSH_CUSTOM diretamente para uma pasta no repo
export ZSH_CUSTOM="$HOME/dotfiles/data/.config/zsh-custom"
# (declare isso no .zshrc, antes de `source $ZSH/oh-my-zsh.sh`)
```

```bash
# Opção B: linkar arquivos individuais de $ZSH_CUSTOM
ln -sf ~/dotfiles/data/.config/zsh-custom/aliases.zsh \
  ~/.oh-my-zsh/custom/aliases.zsh
```

### Estrutura sugerida no repositório

```
dotfiles/
└── data/
    ├── .zshrc                         ← versionado, symlink em ~/.zshrc
    └── .config/
        └── zsh-custom/                ← versionado, aponta para $ZSH_CUSTOM
            ├── aliases.zsh            ← seus atalhos
            ├── functions.zsh          ← suas funções reutilizáveis
            └── env.zsh                ← variáveis de ambiente (sem segredos)
```

Com essa estrutura, ao fazer `git pull` em qualquer máquina, suas customizações chegam imediatamente.

---

## 5. Powerlevel10k: Versionando o Tema

O **Powerlevel10k** é o tema usado neste repositório. Ele tem duas partes:

1. **O tema em si** (`powerlevel10k.zsh-theme`) — dependência externa, não versionada
2. **Sua configuração** (`~/.p10k.zsh`) — seu arquivo, deve ser versionado

### Instalação do tema (dependência)

```bash
git clone --depth=1 https://github.com/romkatv/powerlevel10k.git \
  ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k
```

### Configuração no `.zshrc` (versionado)

```bash
# Instant Prompt — deve ser a PRIMEIRA linha do .zshrc
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# ...resto do .zshrc...

ZSH_THEME="powerlevel10k/powerlevel10k"

# ...ao final do .zshrc:
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh
```

> **Atenção:** o arquivo `~/.p10k.zsh` deve ser versionado no repositório e linkado via symlink — ele contém toda a configuração visual do prompt e é altamente personalizado.

> **Cuidado:** nunca adicione `source ~/powerlevel10k/powerlevel10k.zsh-theme` manualmente no `.zshrc`. O tema é carregado pelo OMZ via `ZSH_THEME`. Um `source` duplicado causa comportamentos estranhos no prompt.

---

## 6. Script de Bootstrap: Automação da Configuração Inicial

Documentar os comandos de instalação em um script garante reprodutibilidade. Crie um `scripts/bootstrap-zsh.sh` no repositório:

```bash
#!/usr/bin/env bash
# scripts/bootstrap-zsh.sh
# Instala dependências do ambiente Zsh em uma máquina nova

set -e

echo "→ Instalando Oh My Zsh..."
if [[ ! -d "$HOME/.oh-my-zsh" ]]; then
  sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
fi

ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"

echo "→ Instalando plugins externos..."
[[ -d "$ZSH_CUSTOM/plugins/zsh-autosuggestions" ]] || \
  git clone https://github.com/zsh-users/zsh-autosuggestions \
    "$ZSH_CUSTOM/plugins/zsh-autosuggestions"

[[ -d "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting" ]] || \
  git clone https://github.com/zsh-users/zsh-syntax-highlighting \
    "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting"

echo "→ Instalando Powerlevel10k..."
[[ -d "$ZSH_CUSTOM/themes/powerlevel10k" ]] || \
  git clone --depth=1 https://github.com/romkatv/powerlevel10k.git \
    "$ZSH_CUSTOM/themes/powerlevel10k"

echo "→ Criando symlinks..."
ln -sf "$DOTFILES/data/.zshrc" "$HOME/.zshrc"

echo "✓ Ambiente Zsh pronto. Execute 'exec zsh' para recarregar."
```

> Com esse script, configurar uma máquina nova é: `git clone` do repositório + executar `bootstrap-zsh.sh`.

---

## 7. Performance

Um terminal lento desmotiva. O OMZ em si é leve, mas a combinação de muitos plugins e ferramentas pesadas no startup pode ultrapassar 500ms. O alvo é **abaixo de 200ms**.

### Lazy Loading para ferramentas pesadas

Ferramentas como `nvm` e `pyenv` são lentas para inicializar. O OMZ tem suporte nativo para lazy loading do `nvm`:

```bash
# ❌ Lento: carrega nvm em TODA abertura de terminal
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

# ✅ Rápido: carrega nvm apenas quando 'nvm', 'node' ou 'npm' forem chamados
zstyle ':omz:plugins:nvm' lazy yes
```

### Controlar atualizações automáticas

Por padrão, o OMZ pode atualizar automaticamente e travar o terminal. Configure-o para só avisar:

```bash
zstyle ':omz:update' mode reminder
```

Depois, atualize quando quiser com `omz update`.

---

## 8. Ferramentas Modernas Complementares

Independentes do OMZ, essas ferramentas escritas em Rust/Go complementam o ambiente com performance muito superior:

| Ferramenta | Substitui / Complementa | Por que usar |
|---|---|---|
| **zoxide** | `cd` — aprende seus diretórios mais usados | Navega para qualquer pasta com 2–3 letras |
| **fzf** | Busca no histórico e em arquivos | Fuzzy finder interativo, integrado ao Ctrl+R |
| **eza** | `ls` — listagem moderna de arquivos | Ícones, cores, Git status integrado |
| **starship** | Temas do OMZ | Prompt cross-shell extremamente rápido |

```bash
# Inicialização no .zshrc (após source $ZSH/oh-my-zsh.sh)
eval "$(zoxide init zsh)"
source <(fzf --zsh)
```

---

## 9. Checklist de Versionamento do OMZ

Use esta lista ao configurar uma máquina nova ou auditar o repositório:

- [ ] `~/.oh-my-zsh/` está no `.gitignore` (ou simplesmente não é rastreado)?
- [ ] Código dos plugins externos (`zsh-autosuggestions`, etc.) está fora do repositório?
- [ ] Existe um script de bootstrap para instalar OMZ + plugins em máquinas novas?
- [ ] Seus arquivos `$ZSH_CUSTOM/*.zsh` estão versionados no repositório?
- [ ] `~/.p10k.zsh` está versionado e linkado via symlink?
- [ ] O Instant Prompt do p10k é a **primeira linha** do `.zshrc`?
- [ ] `source ~/powerlevel10k/powerlevel10k.zsh-theme` **não** existe no `.zshrc` (duplicado)?
- [ ] Ferramentas pesadas (`nvm`, `pyenv`) usam lazy loading?
- [ ] Segredos e tokens estão em `~/.zshrc.local` e fora do repositório?
- [ ] O tempo de startup está abaixo de **200ms**?
