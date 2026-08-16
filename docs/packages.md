# 📦 Pacotes — Instalação de Programas

> Gerencia a instalação dos **programas** (não configurações) usados pelo
> usuário, via lista curada por gerenciador.

## Visão Geral

Os dotfiles cobrem *configurações* (via symlinks em `data/`). Os **programas**
são instalados a partir de uma lista curada que reproduz o ambiente em uma
máquina nova:

- **Lista**: `config/install-packages.list`
- **Script**: `scripts/install-packages.sh`
- **Snapshot (referência)**: `config/packages-snapshot.list` — dump bruto do
  `dpkg -l` da máquina original; **não** é usado para instalação.

## Como Usar

```bash
# Plano (dry-run): mostra o que já está instalado e o que falta.
./scripts/install-packages.sh --dry-run

# Instala com confirmações por gerenciador (pede sudo quando necessário).
./scripts/install-packages.sh --install

# Filtra por um gerenciador:
./scripts/install-packages.sh --install apt
./scripts/install-packages.sh --dry-run flatpak

# Lista crua do arquivo:
./scripts/install-packages.sh --list
```

No menu interativo, use o comando `pkgs`.

## Formato da Lista

Uma entrada por linha: `gerenciador:valor`. Linhas em branco e `#` são
ignoradas (comentários no fim da linha também).

| Gerenciador | Valor | Exemplo | Comando usado |
| :--- | :--- | :--- | :--- |
| `apt` | nome do pacote | `apt:git` | `sudo apt install -y git` |
| `deb` | `binario\|URL` | `deb:code\|https://.../code_amd64.deb` | baixa o `.deb` e `sudo apt install -y` (resolve deps) |
| `flatpak` | app-id | `flatpak:com.spotify.Client` | `flatpak install -y flathub ...` (adiciona Flathub se ausente) |
| `snap` | nome do snap | `snap:code` | `sudo snap install ...` |
| `brew` | fórmula | `brew:atuin` | `brew install ...` (requer brew instalado) |
| `npm` | pacote global | `npm:pnpm` | `npm install -g ...` |
| `pipx` | pacote | `pipx:httpie` | `pipx install ...` |
| `script` | URL | `script:https://.../install.sh` | baixa e **executa** (`bash <(curl -fsSL URL)`) |
| `manual` | texto | `manual:Instalar X: baixe em ...` | apenas imprime instruções; nunca executa |

## Regras e Comportamento

- O script **detecta o que já está instalado** e pula (`dpkg-query`, `flatpak
  info`, `snap list`, `brew list`, `npm ls -g`, `pipx list`).
- Confirmação **por gerenciador** antes de instalar; entradas `script:`
  pedem confirmação **individual** por URL.
- Se o gerenciador não existe no sistema (ex.: `brew` sem Homebrew), a entrada
  é marcada como `sem gerenciador` e é dado um aviso do que instalar primeiro.
- `--install` executa `sudo` quando necessário — no terminal interativo o
  `sudo` pede a senha normalmente.
- Entradas `manual:` são exibidas nos modos `--dry-run` e `--install`, mas
  **nunca executam comandos**.

## Segurança

> [!WARNING]
> - `script:` executa código de terceiros **não auditado**. Só adicione
>   URLs de fontes oficiais que você confia.
> - `deb:` baixa e instala `.deb` de URLs. Verifique a procedência.
> - Revise `config/install-packages.list` antes de rodar `--install`.

## Como Adicionar um Programa Novo

1. Edite `config/install-packages.list` e adicione a linha no formato acima
   (use o `manual:` para programas sem instalador confiável).
2. Confira o plano: `./scripts/install-packages.sh --dry-run`
3. Instale: `./scripts/install-packages.sh --install`
