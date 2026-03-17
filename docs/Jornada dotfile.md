# Passo 1: Automatizando o automatizador

### Vamos usar o Git para salvar  e versionar os `dotfiles`, então vamos começar pelo do proprio Git o `gitconfig`.

#### Ao usar `git init` sem ter o `gitconfig` com `nome` e `email` do github configurado recebemos a seguinte mensagem do git:

```bash
hint: Using 'master' as the name for the initial branch. This default branch name
hint: is subject to change. To configure the initial branch name to use in all
hint: of your new repositories, which will suppress this warning, call:
hint:   git config --global init.defaultBranch <name>
hint: Names commonly chosen instead of 'master' are 'main', 'trunk' and
hint: 'development'. The just-created branch can be renamed via this command:
hint:   git branch -m <name>
Initialized empty Git repository in /home/alfo/dotfiles/.git/
```

o Git está te dá esse aviso porque ainda não definimos uma preferência global. 

### Criando pasta e primeiro arquivo de configuração:

Em vez de rodar o comando que o Git sugeriu diretamente, vamos criar o arquivo dentro da pasta de dotfiles:

```bash
mkdir ~/dotfiles
cd ~/dotfiles
nano gitconfig
```

*(Se preferir o VS Code, pode usar* `code gitconfig`*)*

### O que colocar no arquivo

Cole o conteúdo abaixo. Isso já vai configurar o nome da sua branch padrão para `main` e também identificar você nos commits (importante para o seu novo emprego!):

```properties
[user]
    name = Seu Nome
    email = seu-email@exemplo.com
[init]
    defaultBranch = main
[core]
    editor = nano

```

> Obs: Não use seu email real aqui pra que ele nao fique exposto publicamente. pesquise como obter o "e-mail noreply" do github e use ele. vai ser algo parecido com isso: `1234567+seu-usuario@users.noreply.github.com`

### Criando o Link Simbólico (A "Mágica")

Agora, precisamos dizer ao Debian que as configurações do Git estão nesse arquivo. **Atenção:** se você já tiver um `.gitconfig` na Home, o comando abaixo vai substituí-lo pelo seu novo do `dotfiles`.

```Bash
# Remove o antigo se existir e cria o link
ln -sf ~/dotfiles/gitconfig ~/.gitconfig
```

### Testando o resultado

Agora, qualquer comando Git que você rodar entenderá que a branch padrão é `main`. Para testar se o Git está lendo seu arquivo de dotfiles:

```bash
git config --global init.defaultBranch
# Deve retornar: main
```

### Aqui ja podemos iniciar o repositorio local e fazer o primeiro commit

```bash
git init
git add gitconfig
git commit -m "first commit"
```

---

### Instalar o GitHub CLI

> vamos criar o repositorio via terminal

Se você ainda não tem o `gh` instalado no seu Debian, pode instalá-lo rapidamente:

```Bash
sudo apt update
sudo apt install gh
```

### Autenticação

Antes de criar o repositório, você precisa logar na sua conta:

```Bash
gh auth login
```

- Siga as instruções no terminal.
- Escolha **[GitHub.com](http://GitHub.com)**.
- Prefira a autenticação via **browser** (ele abrirá uma aba para você confirmar um código de 8 dígitos) ou via **token**.

### Criar o Repositório no Github

Como você já deu `git init` e fez o primeiro commit localmente, use o seguinte comando dentro da pasta do projeto:

```Bash
gh repo create nome-do-repositorio --public --source=. --remote=origin --push
```

> Se voce criar com um nome errado (assim como eu) pode renomear com o comando: `gh repo rename novo-nome`

**O que cada flag faz:**

- `--public`: Define o repositório como público (use `--private` se preferir).
- `--source=.`: Indica que o código fonte é o diretório atual.
- `--remote=origin`: Configura automaticamente o "remote" chamado `origin`.
- `--push`: Já envia seus commits locais para o GitHub imediatamente.

---

# Passo 2: Automação com um Script de Instalação

> NOTA: O sistema operacional espera encontrar os arquivos na raiz da sua Home (`~`), mas eles agora estão em `~/dotfiles`. O link simbólico funciona como um "atalho inteligente" que engana o sistema.
>
> **Comando manual:**
>
> ```bash
> # ln -s [CAMINHO_ORIGEM] [CAMINHO_DESTINO]
> ln -s ~/dotfiles/gitconfig ~/.gitconfig
> ```

Para não ter que digitar `ln -s` para cada arquivo em uma máquina nova, crie um arquivo chamado `install.sh` dentro da pasta `~/dotfiles`:

```bash
#!/usr/bin/env bash

# Pasta onde os dotfiles estão
DOTFILES_DIR=~/dotfiles

# Lista de arquivos para linkar (separados por espaço)
files="gitconfig"

echo "AVISO: Este script vai SOBRESCREVER os arquivos existentes em ~ (ex.: ~/.gitconfig)"
echo "       se já existirem. Os arquivos atuais serão substituídos por links simbólicos."
echo ""
read -p "Deseja continuar? (s/n): " -r resposta

if [[ ! "$resposta" =~ ^[sS]$ ]]; then
    echo "Instalação cancelada."
    exit 1
fi

echo ""

for file in $files; do
    echo "Criando link simbólico para $file em ~"
    ln -sf $DOTFILES_DIR/$file ~/.$file
done

echo "Configuração concluída!"

```

*O parâmetro* `-f` *(force) remove o arquivo existente antes de criar o link porque se o arquivo existir o link não pode ser criado.*