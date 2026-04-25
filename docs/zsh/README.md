# Zsh: Versionando no Dotfiles

Este guia ensina **como o `.zshrc` é versionado neste repositório** — desde a estrutura de symlinks até o que deve (e não deve) entrar no Git. O guia parte do pressuposto que você já usa ou vai usar Zsh como shell principal.

> Se você usa Oh My Zsh, leia este guia primeiro. O guia de OMZ parte do conhecimento aqui descrito.
> → [Oh My Zsh: Versionando Plugins e Customizações](../oh-my-zsh/README.md)

---

## 1. A Estratégia: Repositório + Symlink

O arquivo `~/.zshrc` que o Zsh lê **não é o arquivo do repositório** — é um symlink apontando para ele. Quando você edita o symlink, está editando o arquivo no repo. Quando faz `git pull`, a mudança chega automaticamente em todas as máquinas.

```
~/.zshrc  →  ~/dotfiles/data/.zshrc   (symlink → arquivo versionado)
```

### Como criar o symlink

```bash
# Exemplo: linkar o .zshrc do repositório
ln -sf ~/dotfiles/data/.zshrc ~/.zshrc

# Verificar que o link foi criado corretamente
ls -la ~/.zshrc
# Saída esperada: ~/.zshrc -> /home/seu-usuario/dotfiles/data/.zshrc
```

### Como o dotfiles-menu.sh gerencia isso

Este repositório possui um menu interativo que cria e valida os symlinks automaticamente. Para verificar o status de todos os links:

```bash
./dotfiles-menu.sh
```

---

## 2. Estrutura de Arquivos no Repositório

A pasta `data/` contém os arquivos de configuração versionados. Espelhe a estrutura que você precisa em `$HOME`:

```
dotfiles/
└── data/
    ├── .zshrc          ← arquivo principal versionado
    ├── .config/
    │   └── ...         ← outras configs versionadas
    └── ...
```

O `.zshrc` neste repositório **deve ser leve**: carrega o framework, lista plugins e inclui um arquivo local para configurações de máquina específica. Configurações pesadas ficam em arquivos separados.

---

## 3. O Ciclo de Vida da Shell

Toda vez que um terminal abre, o Zsh executa arquivos de configuração em ordem. Saber essa ordem é fundamental para entender *onde* colocar cada coisa:

```
~/.zshenv    ← variáveis de ambiente (sempre executado, inclusive em scripts)
~/.zprofile  ← configurações de login (PATH definitivo, etc.)
~/.zshrc     ← ⭐ arquivo principal (aliases, plugins, prompt) — só em shells interativas
~/.zlogin    ← scripts pós-login
```

**Regra prática:** na quase totalidade dos casos, você só edita o `~/.zshrc`.

---

## 4. Anatomia do `.zshrc` Versionado

O arquivo versionado em `data/.zshrc` segue esta ordem de seções — manter a ordem evita erros onde um alias tenta usar uma ferramenta que ainda não foi carregada:

```bash
# ~/.zshrc — estrutura recomendada para dotfiles

# 1. Instant Prompt (deve ser a PRIMEIRA linha, se usar p10k)
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# 2. Caminho para a instalação do framework
export ZSH="$HOME/.oh-my-zsh"

# 3. Tema e plugins
ZSH_THEME="powerlevel10k/powerlevel10k"
plugins=(git zsh-autosuggestions zsh-syntax-highlighting)

# 4. Carregamento do framework
source $ZSH/oh-my-zsh.sh

# 5. Variáveis de ambiente e PATH
export PATH="$HOME/.local/bin:$PATH"

# 6. Aliases e funções (ou source de $ZSH_CUSTOM)
# (prefira arquivos em $ZSH_CUSTOM/ — ver guia do OMZ)

# 7. Inicializações de ferramentas modernas
eval "$(zoxide init zsh)"

# 8. Arquivo local (segredos, config de máquina específica — NÃO versionado)
[[ -f ~/.zshrc.local ]] && source ~/.zshrc.local
```

---

## 5. O que Versionar vs. O que Ignorar

Esta é a decisão mais importante ao configurar dotfiles:

| O que é                                            | Versionar? | Por quê                                          |
| -------------------------------------------------- | ---------- | ------------------------------------------------ |
| `data/.zshrc`                                      | ✅ Sim      | É a configuração central da sua shell            |
| `~/.zshrc.local`                                   | ❌ Não      | Contém segredos e config de máquina específica   |
| `~/.oh-my-zsh/`                                    | ❌ Não      | É uma dependência externa — instalada por script |
| `~/.oh-my-zsh/custom/plugins/zsh-autosuggestions/` | ❌ Não      | Código de plugin externo — instalado por script  |
| Seus arquivos `$ZSH_CUSTOM/*.zsh`                  | ✅ Sim      | São suas customizações — devem ser versionadas   |
| `~/.p10k.zsh`                                      | ✅ Sim      | Sua configuração visual do prompt                |
| `~/.zsh_history`                                   | ❌ Não      | Dados locais e possivelmente sensíveis           |
| `~/.zcompdump*`                                    | ❌ Não      | Cache gerado automaticamente pelo Zsh            |

### `.gitignore` recomendado

Adicione ao `.gitignore` do repositório:

```gitignore
# Zsh — arquivos que NÃO devem ser versionados
.zsh_history
.zcompdump*
.zshrc.local
```

---

## 6. Segredos: Nunca no `.zshrc` Versionado

O `.zshrc` vai para o repositório Git — possivelmente público. **Nunca coloque tokens, senhas ou chaves de API nele.**

Use o arquivo local (não versionado):

```bash
# ~/.zshrc (versionado) — inclui o arquivo local se existir
[[ -f ~/.zshrc.local ]] && source ~/.zshrc.local

# ~/.zshrc.local (NÃO versionado) — segredos ficam aqui
export GITHUB_TOKEN="ghp_xxx"
export AWS_SECRET_ACCESS_KEY="xxx"
export OPENAI_API_KEY="sk-xxx"
```

> **Dica:** adicione `.zshrc.local` ao `.gitignore` do repositório para garantir que nunca seja commitado por engano.

---

## 7. Histórico do Shell

O histórico do Zsh é uma das ferramentas mais poderosas para produtividade. Configurá-lo bem permite que você recupere comandos complexos digitados meses atrás.

### Configurações de Limite e Arquivo

No Zsh, existem dois limites diferentes para o histórico:

```bash
HISTFILE=~/.zsh_history  # Onde o histórico é salvo no disco
HISTSIZE=10000           # Quantos comandos ficam na MEMÓRIA da sessão atual
SAVEHIST=10000           # Quantos comandos são salvos no ARQUIVO de histórico
```

> [!TIP]
> **HISTSIZE vs SAVEHIST:** O `HISTSIZE` define o que você pode buscar na sessão aberta agora. O `SAVEHIST` define o que será preservado quando você fechar o terminal. Geralmente mantemos os dois com o mesmo valor alto.

### Opções de Comportamento (`setopt`)

Estas opções mudam como o Zsh lida com os comandos que você digita:

*   `HIST_IGNORE_DUPS`: Se você digitar o mesmo comando duas vezes seguidas, ele salva apenas uma vez. Evita poluir o histórico com múltiplos `ls` ou `cd ..`.
*   `HIST_IGNORE_SPACE`: **Fundamental para segurança.** Qualquer comando iniciado com um espaço (ex: `  export KEY=123`) não será gravado no histórico.
*   `SHARE_HISTORY`: Compartilha o histórico em tempo real. Se você digitar um comando no Terminal A, ele estará disponível imediatamente na busca do Terminal B.
*   `HIST_VERIFY`: Quando você usa expansões (como `!!` ou `!$`), o Zsh não executa o comando imediatamente; ele mostra como o comando ficou e espera você dar `Enter` novamente.
*   `HIST_EXPIRE_DUPS_FIRST`: Quando o limite (`SAVEHIST`) é atingido, o Zsh deleta primeiro as duplicatas antigas antes de deletar comandos únicos.

### Como Buscar no Histórico com Eficiência

Não use apenas a "seta para cima". Use estas técnicas:

1.  **Ctrl + R**: Inicia a busca reversa. Digite parte do comando e continue apertando `Ctrl + R` para navegar pelos resultados mais antigos.
2.  **Busca por Prefixo**: Digite o início de um comando (ex: `docker `) e aperte a seta para cima. O Zsh buscará apenas comandos que começam com "docker".
    *   *Nota: Isso depende do plugin `zsh-history-substring-search` ou de binds manuais no `.zshrc`.*

### Comandos Úteis de Gerenciamento

| Objetivo                         | Comando             |
| -------------------------------- | ------------------- |
| Buscar algo específico           | `history            | grep "termo"` |
| Ver os últimos 20 comandos       | `history -20`       |
| Limpar histórico da sessão atual | `history -p`        |
| Limpar arquivo de histórico      | `rm ~/.zsh_history` |

> [!WARNING]
> Nunca versione o seu arquivo `~/.zsh_history`. Ele pode conter informações sensíveis ou comandos privados. Certifique-se de que ele está listado no seu `.gitignore`.

→ [**Guia Passo a Passo: Como aplicar as configurações de histórico**](./tutorial-historico-zsh.md)

---

---

---

## 8. Opções do Zsh (`setopt`)

As mais úteis para o dia a dia:

```bash
# Navegação
setopt AUTO_CD           # digitar o nome de uma pasta entra nela (sem precisar de 'cd')
setopt AUTO_PUSHD        # cd empilha o diretório anterior (navegue com 'popd')
setopt PUSHD_IGNORE_DUPS # não empilha duplicatas

# Globbing (expansão de padrões)
setopt EXTENDED_GLOB     # habilita padrões avançados: ^, #, ~
setopt NULL_GLOB         # se nenhum arquivo corresponder, retorna vazio (sem erro)

# Segurança
setopt NO_CLOBBER        # impede que '>' sobrescreva arquivos (use '>|' para forçar)
```

---

## 9. Aliases e Funções: Onde Colocar

Em vez de poluir o `.zshrc`, mantenha aliases e funções em arquivos separados:

```bash
# Com Oh My Zsh: coloque em $ZSH_CUSTOM/ — carregado automaticamente
~/.oh-my-zsh/custom/aliases.zsh
~/.oh-my-zsh/custom/functions.zsh

# Sem framework: crie um arquivo e adicione source no .zshrc
~/.zsh_aliases
# ~/.zshrc: source ~/.zsh_aliases
```

No contexto deste dotfiles, os arquivos `$ZSH_CUSTOM/*.zsh` são versionados e chegam ao lugar certo via symlink da pasta `custom/`. Veja o guia do OMZ para detalhes.

---

## 10. Recarregando Configurações

Após editar o `.zshrc`, **nunca use `source ~/.zshrc`**. Isso executa o arquivo dentro da sessão já inicializada, causando "double sourcing" — plugins duplicados, variáveis sobrepostas, comportamentos estranhos.

Use sempre:

```bash
exec zsh
```

Esse comando **substitui** o processo atual por uma nova sessão Zsh limpa.

---

## 11. Medindo Performance do Startup

O tempo de carregamento ideal é **abaixo de 200ms**. Qualquer coisa acima começa a ser perceptível.

```bash
# Medir 10 vezes para ter uma média confiável
for i in {1..10}; do time zsh -i -c exit; done
```

Se houver lentidão, use o profiler do Zsh para identificar o culpado:

```bash
# Adicione NO INÍCIO do ~/.zshrc:
zmodload zsh/zprof

# ... resto das configurações ...

# Adicione NO FINAL do ~/.zshrc:
zprof
```

Abra um novo terminal. O relatório listará cada função com seu tempo. Após identificar o problema, **remova as linhas do `zprof`**.

| Causa comum de lentidão            | Solução                                                 |
| ---------------------------------- | ------------------------------------------------------- |
| `nvm`, `pyenv`, `rbenv` no startup | Lazy loading — carregue só quando o comando for chamado |
| Muitos plugins OMZ ativos          | Audite e remova os que não usa diariamente              |
| Tema com consultas Git síncronas   | Use Powerlevel10k (Instant Prompt) ou Starship          |
| `source` de scripts grandes        | Prefira lazy loading com funções                        |

---

## 12. Checklist de Versionamento

Use esta lista ao configurar uma máquina nova ou revisar o repositório:

- [ ] O symlink `~/.zshrc → dotfiles/data/.zshrc` existe e aponta para o lugar certo?
- [ ] `.zshrc.local` está no `.gitignore` e nunca foi commitado?
- [ ] Segredos e tokens estão **apenas** em `~/.zshrc.local`?
- [ ] `~/.zsh_history` e `~/.zcompdump*` estão no `.gitignore`?
- [ ] Aliases e funções estão em arquivos separados (não diretamente no `.zshrc`)?
- [ ] O tempo de startup está abaixo de **200ms**?
- [ ] `exec zsh` é usado para recarregar (nunca `source ~/.zshrc`)?
