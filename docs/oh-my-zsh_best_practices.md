# Melhores Práticas para Oh My Zsh (Dotfiles)

Este guia documenta como configurar, organizar e otimizar o Zsh com Oh My Zsh de forma que seja rápida, modular e fácil de manter. O conteúdo segue uma progressão gradual: comece do início e vá avançando conforme ganha confiança.

---

## 1. Entendendo a Estrutura (Por Onde Começar)

Antes de otimizar qualquer coisa, é importante entender **o que acontece quando você abre um terminal**.

Quando uma nova shell Zsh inicia, ela executa os arquivos na seguinte ordem:

1. `/etc/zsh/zshenv` — variáveis de ambiente globais do sistema
2. `~/.zshenv` — suas variáveis de ambiente pessoais
3. `~/.zshrc` — **seu arquivo principal** (plugins, temas, aliases)

O `~/.zshrc` é o coração da sua configuração. É nele que o Oh My Zsh é carregado. Por isso, tudo que está aqui é executado **toda vez que você abre um novo terminal** — e é exatamente por isso que seu conteúdo importa tanto para a performance.

---

## 2. Instalação e Primeiros Passos

Se ainda não instalou o Oh My Zsh, o comando oficial é:

```bash
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
```

Após a instalação, o OMZ cria automaticamente um `~/.zshrc` com exemplos comentados. As configurações mais importantes que você vai querer ajustar logo de início são:

```bash
# Tema visual do terminal
ZSH_THEME="robbyrussell"

# Plugins ativos (começe com poucos!)
plugins=(git zsh-autosuggestions zsh-syntax-highlighting)
```

> **Regra de ouro:** Comece com 2–3 plugins essenciais. É muito mais fácil adicionar depois do que diagnosticar lentidão causada por excesso.

---

## 3. Plugins Essenciais (e o que Cada Um Faz)

Não ative plugins por ativar. Cada um tem um custo de performance. Aqui estão os que valem o custo:

| Plugin | O que faz | Por que usar |
|---|---|---|
| `git` | Aliases curtos para Git (`gst`, `gco`, `gl`...) | Economiza tempo em operações do dia a dia |
| `zsh-autosuggestions` | Sugere comandos anteriores enquanto você digita | Reduz retrabalho com histórico de forma visual |
| `zsh-syntax-highlighting` | Coloriza o comando atual: verde se válido, vermelho se inválido | Pega erros de digitação antes de pressionar Enter |

> **Atenção:** `zsh-autosuggestions` e `zsh-syntax-highlighting` são **plugins externos** — não vêm com o OMZ. Você precisa cloná-los manualmente em `$ZSH_CUSTOM/plugins/` antes de listá-los no `.zshrc`.

**Plugins que parecem úteis mas raramente valem o custo:**
- Plugins de linguagens (`ruby`, `python`, `node`) — geralmente adicionam centenas de aliases que você nunca vai usar e aumentam o tempo de carregamento.

---

## 4. Modularização com `$ZSH_CUSTOM`

Manter tudo no `.zshrc` é a armadilha mais comum. Com o tempo, ele vira um arquivo gigante e difícil de entender.

A solução é usar a pasta `$ZSH_CUSTOM` (padrão: `~/.oh-my-zsh/custom/`). **O OMZ carrega automaticamente qualquer arquivo `.zsh` dentro dessa pasta**, então você pode dividir suas configurações em arquivos menores e temáticos:

```
~/.oh-my-zsh/custom/
  aliases.zsh      ← todos os seus atalhos
  env.zsh          ← variáveis de ambiente (PATH, tokens, etc.)
  functions.zsh    ← funções customizadas reutilizáveis
```

No contexto do seu dotfiles, esses arquivos ficam no repositório e são linkados (via symlink) para os locais esperados. Essa separação tem dois benefícios: o `.zshrc` fica limpo, e suas personalizações ficam isoladas das atualizações do OMZ — que sobrescrevem apenas os arquivos internos do framework, nunca os seus.

---

## 5. Temas e Prompt Rápido (Powerlevel10k)

O tema define a aparência do seu prompt. Temas simples (como `robbyrussell`) são rápidos. Temas complexos podem ser lentos em repositórios grandes, pois precisam consultar o status do Git a cada comando.

O **Powerlevel10k** é a solução para ter um prompt rico **sem sacrificar velocidade**, graças ao seu recurso de **Instant Prompt**:

```bash
# Deve ser a PRIMEIRA coisa no seu .zshrc, antes de tudo
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
done
```

Como o Instant Prompt funciona: ele renderiza o prompt visual imediatamente, enquanto o restante do `.zshrc` ainda está carregando em background. O terminal responde na hora, sem nenhuma espera visível.

**Cuidado:** a linha `source .../p10k.zsh-theme` deve aparecer **apenas uma vez** no `.zshrc`. Carregamentos duplicados causam comportamentos estranhos no prompt.

---

## 6. Performance (O Inimigo nº 1 do Terminal)

Um terminal lento desmotiva. O tempo de carregamento ideal é **abaixo de 200ms**. Se estiver acima disso, você provavelmente tem algum código pesado sendo executado no startup.

### Passo 1: Meça antes de otimizar

```bash
# Mede o tempo de 10 aberturas consecutivas de shell
for i in {1..10}; do time zsh -i -c exit; done
```

> **Nota:** Se o comando acima falhar, use o GNU time: `for i in {1..10}; do /usr/bin/time zsh -i -c exit; done`

### Passo 2: Identifique o culpado

Se a medição revelar lentidão, use o profiler embutido do Zsh para saber **qual linha específica** está demorando:

```bash
# Adicione no INÍCIO do seu .zshrc:
zmodload zsh/zprof

# ... resto das suas configurações ...

# Adicione no FINAL do seu .zshrc:
zprof
```

Abra um novo terminal. O `zprof` vai imprimir um relatório com o tempo gasto em cada função. Identifique os maiores ofensores e trate-os com lazy loading (próxima seção).

> Lembre de **remover** as linhas do `zprof` após o diagnóstico.

### Passo 3: Lazy Loading para ferramentas pesadas

Ferramentas como `nvm`, `pyenv`, `rbenv` e `sdkman` são lentas para inicializar. **Nunca** carregue-as diretamente no `.zshrc` — faça lazy loading: carregue apenas quando o comando for realmente chamado.

```bash
# ❌ Lento: carrega nvm em TODA abertura de terminal
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

# ✅ Rápido: carrega nvm apenas quando 'nvm', 'node' ou 'npm' forem usados
zstyle ':omz:plugins:nvm' lazy yes
```

---

## 7. Atualizações e Manutenção do Dia a Dia

### Recarregar o `.zshrc`

Após editar o `.zshrc`, **nunca use `source ~/.zshrc`** para aplicar as mudanças. Esse comando executa o arquivo dentro da sessão atual, causando "double sourcing" que pode bugar plugins e criar variáveis duplicadas. Use sempre:

```bash
exec zsh
```

Esse comando **substitui** o processo da shell atual por uma nova sessão limpa — exatamente o que acontece quando você abre um novo terminal.

### Controlar atualizações automáticas

Por padrão, o OMZ pode atualizar automaticamente e travar seu terminal em um momento inconveniente. Configure-o para apenas te avisar:

```bash
zstyle ':omz:update' mode reminder
```

Assim, você atualiza quando quiser, com o comando `omz update`.

### Proteger segredos

**Nunca** coloque tokens de API, senhas ou chaves privadas no `.zshrc` — ele vai para o repositório de dotfiles. Use um arquivo separado que fica **fora** do controle de versão:

```bash
# No seu .zshrc, carregue um arquivo local (não commitado)
[[ -f ~/.zshrc.local ]] && source ~/.zshrc.local
```

Adicione `*.local` ao `.gitignore` do seu dotfiles.

---

## 8. Ferramentas Modernas Complementares

À medida que você fica mais confortável, algumas ferramentas escritas em Rust/Go podem substituir ou complementar funcionalidades do OMZ com performance muito superior:

| Ferramenta | Substitui / Complementa | Por que usar |
|---|---|---|
| **zoxide** | `cd` — aprende seus diretórios mais usados | Navega para qualquer pasta com 2-3 letras |
| **fzf** | Busca no histórico e em arquivos | Fuzzy finder interativo integrado ao terminal |
| **starship** | Temas do OMZ | Prompt cross-shell rápido, alternativa ao p10k |

Essas ferramentas se integram ao Zsh via uma linha no `.zshrc` (ex: `eval "$(zoxide init zsh)"`) e não dependem do OMZ para funcionar.

---

## 9. Checklist Final

Use esta lista para auditar sua configuração sempre que adicionar algo novo:

- [ ] O Instant Prompt do p10k está como **primeira linha** do `.zshrc`?
- [ ] Os plugins externos (`zsh-autosuggestions`, `zsh-syntax-highlighting`) estão clonados em `$ZSH_CUSTOM/plugins/`?
- [ ] Existe algum `source` de ferramenta pesada (`nvm`, `pyenv`) que poderia ser lazy-loaded?
- [ ] Aliases e funções estão em arquivos separados em `$ZSH_CUSTOM/`, não diretamente no `.zshrc`?
- [ ] O arquivo está livre de aliases duplicados?
- [ ] Segredos e tokens estão em `~/.zshrc.local` e **fora** do repositório?
- [ ] O tempo de startup está abaixo de **200ms**?
