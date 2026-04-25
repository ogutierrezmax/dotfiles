# Guia Passo a Passo: Aplicando Configurações de Histórico

Este tutorial ensina como aplicar as configurações de histórico do Zsh descritas no guia principal. Como estamos usando um sistema de **dotfiles versionados**, não editamos o arquivo diretamente no `$HOME`, mas sim dentro da pasta do repositório.

---

## Passo 1: Localize o arquivo versionado

O seu arquivo principal de configuração é o `.zshrc`. No contexto deste repositório, ele fica em:

```text
~/dotfiles/data/.zshrc
```

Abra-o com o seu editor de preferência (ex: `nano`, `vim`, `code`).

## Passo 2: Copie o bloco de configuração

Copie o bloco abaixo, que contém as definições de limites e as opções de comportamento recomendadas:

```bash
# --- Configurações de Histórico do zsh---
HISTFILE=~/.zsh_history  # Arquivo onde o histórico é salvo
HISTSIZE=10000           # Comandos na memória da sessão
SAVEHIST=10000           # Comandos preservados no disco

setopt HIST_IGNORE_DUPS      # Ignora duplicatas consecutivas
setopt HIST_IGNORE_SPACE     # Comandos com espaço inicial não são salvos
setopt SHARE_HISTORY         # Compartilha histórico entre terminais
setopt HIST_VERIFY           # Revisa comando antes de executar com !!
setopt HIST_EXPIRE_DUPS_FIRST # Deleta duplicatas primeiro ao atingir o limite
# ----------------------------------
```

## Passo 3: Onde colar no arquivo?

Para manter a organização, cole este bloco antes da seção de **Aliases** ou seguindo a estrutura de seções sugerida no [README principal](./README.md#4-anatomia-do-zshrc-versionado).

## Passo 4: Salve e Recarregue a Shell

Após salvar o arquivo `~/dotfiles/data/.zshrc`, as mudanças ainda não estarão ativas no seu terminal atual. Para aplicá-las, você tem duas opções:

1.  **Opção recomendada**: Execute o comando abaixo:
    ```bash
    exec zsh
    ```
2.  **Opção alternativa**: Feche o terminal e abra um novo.

> [!IMPORTANT]
> Evite usar `source ~/.zshrc`, pois isso pode causar carregamento duplo de plugins e lentidão. O `exec zsh` é mais limpo.

## Passo 5: Validando se funcionou

Para testar se a configuração de segurança está ativa, digite um comando começando com um espaço:

```bash
  echo "isso não deve aparecer no history"
```

Depois, digite `history`. O comando acima **não** deve constar na lista. Se isso aconteceu, parabéns! Seu histórico está configurado corretamente.

---
[← Voltar para o README do Zsh](./README.md)
