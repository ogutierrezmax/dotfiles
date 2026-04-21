# Melhores Práticas para Oh My Zsh (Dotfiles)

Este guia documenta como manter uma configuração do Zsh (utilizando Oh My Zsh) que seja rápida, modular e fácil de manter.

## 1. Performance (O Inimigo nº 1)

O Oh My Zsh pode se tornar lento se não for gerenciado com cuidado. O tempo de carregamento do terminal deve ser idealmente < 200ms.

### Profiling do Startup
Sempre meça antes de otimizar. Execute este comando para ver quanto tempo leva para abrir uma nova shell (usando o `time` interno do shell):
```bash
for i in {1..10}; do time zsh -i -c exit; done
```
*Nota: Se o comando acima falhar ou você quiser detalhes extras, instale o utilitário GNU time (`sudo apt install time`) e use `/usr/bin/time`. Exemplo: `for i in {1..10}; do /usr/bin/time zsh -i -c exit; done`* 

### Lazy Loading (Carregamento Preguiçoso)
Ferramentas como `nvm`, `pyenv` ou `sdkman` são lentas para inicializar. **Nunca** dê `source` nelas diretamente no `.zshrc`.
- Use plugins de lazy loading (ex: `zsh-nvm`) ou funções wrapper.
- **Exemplo para NVM:**
  ```bash
  # Em vez de carregar no startup, carregue apenas quando 'nvm', 'node' ou 'npm' forem usados
  zstyle ':omz:plugins:nvm' lazy yes
  ```

### Evite o Excesso de Plugins
Cada plugin adiciona tempo de execução. Ative apenas o que você realmente usa diariamente.
- **Recomendados:** `git`, `zsh-autosuggestions`, `zsh-syntax-highlighting`.
- **Cuidado:** Plugins de linguagens (ruby, python, node) geralmente apenas adicionam centenas de aliases que você raramente usa.

---

## 2. Modularização com `$ZSH_CUSTOM`

Mantenha seu arquivo `.zshrc` limpo. O Oh My Zsh carrega automaticamente qualquer arquivo `.zsh` dentro de `$ZSH_CUSTOM` (geralmente `~/.oh-my-zsh/custom/`).

### Estrutura Recomendada:
- `$ZSH_CUSTOM/aliases.zsh`: Todos os seus atalhos.
- `$ZSH_CUSTOM/env.zsh`: Variáveis de ambiente.
- `$ZSH_CUSTOM/functions.zsh`: Funções customizadas.

Dessa forma, ao atualizar o Oh My Zsh, suas configurações permanecem isoladas e organizadas.

---

## 3. Temas e UI (Powerlevel10k)

Se você usa o **Powerlevel10k**, aproveite o **Instant Prompt**.
- Ele deve ser a primeira coisa no seu `.zshrc`.
- Ele renderiza o prompt instantaneamente enquanto o resto do shell carrega em background.

**Atenção:** Evite carregar o tema manualmente múltiplas vezes. Certifique-se de que a linha `source .../p10k.zsh-theme` aparece apenas uma vez.

---

## 4. Atualizações e Manutenção

- **Modo de Atualização:** Configure o OMZ para lembrar você de atualizar, em vez de atualizar automaticamente e travar sua shell quando você está com pressa.
  ```bash
  zstyle ':omz:update' mode reminder
  ```
- **Recarregar Configurações:** **NUNCA** use `source ~/.zshrc` para aplicar mudanças. Isso causa "double sourcing" e pode bugar plugins. Use:
  ```bash
  exec zsh
  ```
  Isso substitui a shell atual por uma nova, limpa.

---

## 5. Ferramentas Modernas Complementares

Em vez de depender apenas de plugins do OMZ, use ferramentas escritas em linguagens rápidas (Rust/Go):
- **zoxide:** Substituto ultra-rápido para o `cd`.
- **fzf:** Fuzzy finder para histórico e arquivos.
- **starship:** Prompt cross-shell extremamente rápido (alternativa ao p10k).

---

## 6. Checklist para o seu .zshrc

- [ ] Instant Prompt do p10k está no topo?
- [ ] Plugins externos (`zsh-autosuggestions`) estão instalados?
- [ ] Existe algum `source` de ferramenta pesada que pode ser lazy-loaded?
- [ ] O arquivo está livre de aliases duplicados?
