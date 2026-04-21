# Boas Práticas para .bashrc (Dotfiles)

Este documento descreve os princípios e padrões recomendados para organizar e manter o arquivo `.bashrc` e configurações relacionadas neste repositório.

## 1. Modularização (Divisão de Responsabilidades)

Um arquivo `.bashrc` gigante é difícil de manter. A recomendação moderna é dividir as configurações em arquivos menores e mais específicos.

### Estrutura Sugerida:
- `~/.bashrc.d/`: Pasta para armazenar módulos.
  - `00-env.sh`: Variáveis de ambiente e caminhos (`PATH`).
  - `10-aliases.sh`: Atalhos de comandos.
  - `20-functions.sh`: Funções shell complexas.
  - `30-prompt.sh`: Customização do PS1.
  - `40-completions.sh`: Configurações de auto-complete.

### Carregamento Automático:
No seu `.bashrc` principal, use um loop para carregar todos os módulos:

```bash
if [ -d "$HOME/.bashrc.d" ]; then
    for config in "$HOME/.bashrc.d/"*.sh; do
        [ -r "$config" ] && source "$config"
    done
fi
```

## 2. Performance e Otimização

O tempo de abertura do terminal deve ser o menor possível.

- **Use Built-ins do Shell**: Prefira `[[ ... ]]` em vez de `[ ... ]` ou `test`, e use expansão de parâmetros do Bash `${var#pattern}` em vez de chamar `sed` ou `cut`.
- **Lazy Loading**: Não carregue ferramentas pesadas (como `nvm`, `rvm` ou `sdkman`) no startup. Use wrappers que carregam a ferramenta apenas no primeiro uso.
- **Evite Subshells**: Minimiza chamadas como `$(date)` ou `$(uname)` dentro do loop de startup se os valores puderem ser cacheados ou evitados.

## 3. Idempotência e Segurança

Scripts e configurações devem ser seguros para rodar múltiplas vezes.

- **Verifique antes de Sourcing**: Sempre teste se um arquivo existe e pode ser lido antes de dar `source`.
  ```bash
  [ -f "$HOME/.bashrc.local" ] && . "$HOME/.bashrc.local"
  ```
- **Filtro de Shell Interativo**: Certifique-se de que aliases e customizações de UI rodem apenas em shells interativos.
  ```bash
  # Se não for interativo, não faça nada
  [[ $- != *i* ]] && return
  ```
- **XDG Base Directory**: Siga o padrão XDG para manter a sua `HOME` limpa.
  - Use `~/.config/bash/bashrc` em vez de `~/.bashrc` se possível.
  - Defina `XDG_CONFIG_HOME`, `XDG_DATA_HOME` e `XDG_CACHE_HOME`.

## 4. Gerenciamento de Segredos

**NUNCA** coloque tokens de API, senhas ou chaves privadas no seu repositório de dotfiles.

- Use um arquivo `.bashrc.local` ou `.env` que seja incluído no `.gitignore`.
- Utilize gerenciadores de segredos (como `pass`, `1password CLI` ou `bitwarden CLI`) para injetar variáveis em tempo de execução.

## 5. Qualidade de Código

- **ShellCheck**: Use a ferramenta [ShellCheck](https://www.shellcheck.net/) para validar seus scripts. Ela identifica bugs comuns e problemas de portabilidade.
- **Comentários**: Explique o "porquê" de certas configurações obscuras ou hacks.
- **Strict Mode para Scripts**: Em scripts de instalação (`install.sh`), use:
  ```bash
  set -euo pipefail
  ```

## 6. Portabilidade

- **Verificação de SO/Distro**: Se você usa diferentes máquinas (Mac, Ubuntu, Arch), faça verificações condicionais:
  ```bash
  if [[ "$OSTYPE" == "darwin"* ]]; then
      # Configs específicas para macOS
  fi
  ```
