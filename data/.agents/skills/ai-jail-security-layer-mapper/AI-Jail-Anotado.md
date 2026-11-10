# `AI Jail.md` — Anotação Completa

## Cabeçalho e introdução (linhas 1–57)

O arquivo original explica o **motivo** do jail: agentes de IA (Cursor, Claude Code, etc.) têm acesso ao sistema de arquivos e podem, por acidente ou supply-chain attack, executar comandos destrutivos. A solução proposta é o **Bubblewrap (`bwrap`)** — mesma tecnologia usada pelo Flatpak.

```bash
bwrap --ro-bind /usr /usr \
      --ro-bind /bin /bin \
      --ro-bind /lib /lib \
      --ro-bind /lib64 /lib64 \
      --dev /dev \
      --proc /proc \
      --bind $(pwd) $(pwd) \
      --chdir $(pwd) \
      --unshare-all \
      --share-net \
      bash
```

| Flag | O que faz | Pra que serve |
|------|-----------|--------------|
| `--ro-bind /usr /usr` | Monta `/usr` como read-only | **Dar acesso a programas e bibliotecas do sistema sem permitir alterações** — a IA precisa de ferramentas como Python, Node, git, etc., mas não deve poder modificar nada |
| `--dev /dev` | Cria um `/dev` mínimo isolado | **Fornecer dispositivos essenciais** (null, random, tty, urandom) para que processos dentro do sandbox não quebrem por falta de `/dev/null` ou `/dev/random` |
| `--proc /proc` | Monta um `/proc` isolado | **Manter compatibilidade** — muitos comandos (ps, top, etc.) precisam de `/proc` para funcionar; o isolamento impede que a IA veja processos do host |
| `--bind $(pwd) $(pwd)` | Monta o diretório atual com leitura/escrita | **Criar o workspace do jail** — é o único lugar onde a IA pode escrever arquivos; tudo que ela fizer fica restrito a este diretório |
| `--unshare-all` | Isola todos os namespaces Linux (PID, mount, IPC, UTS...) | **Impedir que a IA enxergue ou interfira com o resto do sistema** — ela não vê outros processos, não acessa outros mounts, não vê o hostname real |
| `--share-net` | **Exceção**: compartilha a rede do host | **Permitir que a IA acesse a internet** — sem isso ela não consegue instalar pacotes npm, pip, consultar APIs, etc. |
| `bash` | Executa um shell bash dentro do sandbox | **Ponto de entrada** — o shell que vai rodar os comandos do agente de IA |

---

## Script completo (`~/.local/bin/ai-jail`) — linhas 59–240

### Shebang e cabeçalho (linhas 59–68)

```bash
#!/bin/bash

# ai-jail — bubblewrap sandbox for AI coding agents
# Mounts the project dir read-write, auto-discovers home dotfiles with a
# deny-list for sensitive dirs, and isolates namespaces.
#
# Usage: ai-jail [--map PATH]... COMMAND [ARGS...]
#        ai-jail claude
#        ai-jail bash
```

**O que faz:** Script bash que serve de entrada para o sandbox. Recebe um comando opcional (ex.: `ai-jail crush`) e, se omitido, usa `bash` como padrão.

**Pra que serve:** **Empacotar toda a lógica complexa do jail em um comando simples.** Em vez de decorar dezenas de flags do `bwrap` toda vez, o usuário só digita `ai-jail claude` e o sandbox já sobe com todas as proteções.

---

### Variáveis iniciais (linhas 70–71)

```bash
PROJECT_DIR=$(pwd)
TEMP_HOSTS=$(mktemp /tmp/bwrap-hosts.XXXXXX)
```

**O que faz:**
- `PROJECT_DIR` captura o diretório atual como workspace
- `TEMP_HOSTS` cria um arquivo temporário único em `/tmp/`

**Pra que serve:**
- **Saber qual diretório montar com permissão de escrita** — `PROJECT_DIR` é o único lugar onde a IA poderá salvar arquivos. O resto do sistema fica invisível ou read-only.
- **Criar um `/etc/hosts` customizado** — o `TEMP_HOSTS` será montado como `/etc/hosts` dentro do sandbox para **bloquear domínios específicos** (APIs de IA, telemetria, etc.) ou redirecionar DNS. O `mktemp` com `XXXXXX` garante nome único para não colidir com outros processos.

---

### Trap de limpeza (linha 73)

```bash
trap 'rm -f "$TEMP_HOSTS"' EXIT
```

**O que faz:** Registra um gancho que executa `rm -f "$TEMP_HOSTS"` automaticamente quando o script terminar (sucesso, erro, `Ctrl+C`, `kill`).

**Pra que serve:** **Não deixar lixo em `/tmp/`.** Se o script for interrompido no meio (crash, Ctrl+C), o arquivo temporário seria esquecido. O `trap` garante limpeza automática — equivalente a um `finally`/`defer` de outras linguagens.

---

### Descoberta do Mise (linha 76)

```bash
REAL_MISE_BIN=$(type -p mise 2>/dev/null || echo "")
```

**O que faz:** Procura o caminho absoluto do executável `mise` no `$PATH`. Se não achar, a variável fica vazia.

**Pra que serve:** **Descobrir dinamicamente onde o `mise` está instalado** para montá-lo dentro do sandbox. O `mise` (ex-`rtx`) gerencia versões de Node, Python, Go, etc. — sem ele dentro do sandbox, a IA não conseguiria usar as runtimes corretas do projeto. A detecção automática evita hardcodar caminhos que variam de máquina pra máquina.

---

### Descoberta do NVM (pós-linha 45, adicionado pelo Security Layer Mapper)

```bash
NVM_DIR="${NVM_DIR:-$HOME/.nvm}"
NVM_INIT="true"
if [ -s "$NVM_DIR/nvm.sh" ]; then
    NVM_INIT="export NVM_DIR=\"$NVM_DIR\" && [ -s \"\$NVM_DIR/nvm.sh\" ] && \\. \"\$NVM_DIR/nvm.sh\" && [ -s \"\$NVM_DIR/bash_completion\" ] && \\. \"\$NVM_DIR/bash_completion\""
fi
```

**O que faz:** Detecta se o NVM (Node Version Manager) está instalado em `~/.nvm` e, se sim, monta um comando de inicialização que exporta `NVM_DIR`, carrega `nvm.sh` e o `bash_completion`.

**Pra que serve:** **Suporte a runtime Node.js via nvm** — sistemas que usam nvm em vez de mise (como este sistema) precisam que o nvm seja explicitamente carregado dentro do sandbox. Sem isso, Node/npm podem não estar no `$PATH` ou estar em versões não esperadas.

| Mapeamento | Detalhe |
|-----------|---------|
| **Conceito similar** | `nvm` ↔ `mise`: ambos gerenciam versões de runtime |
| **Sistema real** | NVM instalado em `$NVM_DIR="$HOME/.nvm"`, carregado em `~/.zshrc` e `~/.zsh/env.zsh` |
| **.nvm no jail** | Adicionado a `DOTDIR_RW` para permitir que nvm instale/gerencie versões |
| **Config existente** | `~/.zshrc` linha 20: `[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"` |
| **Sincronizado?** | ✅ NVM init adicionado ao jail; `.nvm` em DOTDIR_RW; sync com zshrc |

> **⚠️ Nota:** Se `mise` também estiver instalado, ambos são inicializados (`$MISE_INIT && $NVM_INIT`). O mise é executado primeiro.

---

### Popula o `/etc/hosts` customizado (linha 79)

```bash
printf '127.0.0.1 localhost ai-sandbox\n::1       localhost ai-sandbox\n' > "$TEMP_HOSTS"
```

**O que faz:** Escreve entradas de localhost (IPv4 e IPv6) no arquivo temporário, incluindo o alias `ai-sandbox`.

**Pra que serve:** **Garantir que a resolução de `localhost` funcione dentro do sandbox.** Muitas ferramentas (especialmente em Go) falham se `/etc/hosts` não tiver uma entrada explícita para `localhost`. O alias `ai-sandbox` é opcional, mas útil para identificar o hostname dentro do jail.

---

### Parsing de `--map` / `--rw-map` (linhas 81–96)

```bash
EXTRA_MOUNTS=()
while [[ "${1:-}" == --map || "${1:-}" == --rw-map ]]; do
    FLAG="$1"
    MAP_PATH="$2"
    if [ -e "$MAP_PATH" ]; then
        if [[ "$FLAG" == "--rw-map" ]]; then
            EXTRA_MOUNTS+=("--bind" "$MAP_PATH" "$MAP_PATH")
        else
            EXTRA_MOUNTS+=("--ro-bind" "$MAP_PATH" "$MAP_PATH")
        fi
    else
        echo "Warning: Path $MAP_PATH not found, skipping." >&2
    fi
    shift 2
done
```

**O que faz:** Processa argumentos `--map PATH` (read-only) e `--rw-map PATH` (read-write) para montar diretórios adicionais dentro do sandbox.

**Pra que serve:** **Permitir que o usuário monte pastas extras sem editar o script.** Ex.: `ai-jail --map /home/user/outro-projeto claude` — útil para projetos que dependem de bibliotecas ou dados localizados fora do diretório atual. Se o caminho não existe, avisa mas não quebra (comportamento tolerante).

---

### Inicialização do Mise (linhas 98–103)

```bash
if [ -n "$REAL_MISE_BIN" ]; then
    MISE_INIT="$REAL_MISE_BIN trust && eval \"\$($REAL_MISE_BIN activate bash)\" && eval \"\$($REAL_MISE_BIN env)\""
else
    MISE_INIT="true"
fi
```

**O que faz:** Se o `mise` foi encontrado, monta um comando que: (1) confia no `.mise.toml` do projeto, (2) ativa hooks no shell, (3) exporta variáveis de ambiente das runtimes. Se não, usa `true` (comando nulo).

**Pra que serve:** **Preparar o ambiente de desenvolvimento dentro do sandbox.** Sem o mise, Node, Python, Go, etc. podem não estar no `PATH` ou estar em versões erradas. Esse comando é injetado no `bash -c` final (linha 239) para que a IA já entre num ambiente funcional.

---

### Deny-lists (linhas 105–112)

```bash
DOTDIR_DENY=(.gnupg .aws .mozilla .basilisk-dev .sparrow .ssh .steam .pki .var .android .gemini .ollama)

CONFIG_DENY=(BraveSoftware Bitwarden google-chrome google-chrome-for-testing discord Discord gh Pinokio warp-terminal obsidian Docker Desktop Code)

CACHE_DENY=(BraveSoftware basilisk-dev chromium spotify nvidia mesa_shader_cache google-chrome)
```

**O que faz:** Define listas de diretórios que **nunca** devem ser montados dentro do sandbox.

**Pra que serve:** **Proteger dados sensíveis do usuário.** Se a IA tiver acesso a chaves GPG (`.gnupg`), credenciais AWS (`.aws`), perfil do Firefox (`.mozilla`), ou senhas do Bitwarden, um comportamento malicioso ou acidental poderia exfiltá-los. Essas listas são a **principal barreira de privacidade** do jail.

### Mapeamento de Segurança — Deny-Lists

| Item | Categoria | Risco | Descoberto pelo Security Layer Mapper |
|------|-----------|-------|---------------------------------------|
| `.ssh` | Credenciais | 🔴 Crítico — chaves SSH privadas | Já existia no script real mas não no anotado (sincronizado) |
| `.ollama` | Chaves criptográficas | 🔴 Alto — contém `id_ed25519` (par de chaves) | **GAP:** Não estava em nenhuma lista. Adicionado ao DOTDIR_DENY. |
| `.pki` | Certificados TLS | 🟡 Médio — certificados e chaves PKI | Já existia no script real (sincronizado) |
| `.steam` | Sessões/games | 🟢 Baixo — dados de jogos | Já existia no script real (sincronizado) |
| `.var` | Flatpak | 🟡 Médio — sandbox escape vector | Já existia no script real (sincronizado) |
| `.gemini` | AI credenciais | 🟡 Médio — possíveis tokens API | Já existia no script real (sincronizado) |
| `google-chrome` | Navegador | 🔴 Alto — cookies, sessões, senhas | Adicionado ao CONFIG_DENY e CACHE_DENY |
| `Code` | IDE | 🟡 Médio — tokens, sessões VS Code | Adicionado ao CONFIG_DENY |
| `discord/Discord` | Comunicação | 🟡 Médio — tokens de sessão | Já existia (sincronizado) |
| `gh` | Git CLI | 🟡 Médio — tokens GitHub | Já existia (sincronizado) |
| `warp-terminal` | Terminal | 🟡 Médio — histórico, sessões | Já existia (sincronizado) |
| `obsidian` | Notas | 🟢 Baixo — notas pessoais | Já existia (sincronizado) |
| `Docker Desktop` | Container | 🟡 Médio — config de containers | Já existia (sincronizado) |
| `Pinokio` | App manager | 🟢 Baixo — app configs | Já existia (sincronizado) |

### Conceitos similares em outras ferramentas

| Ferramenta | Conceito similar | Config | Sincronizado? |
|-----------|-----------------|--------|---------------|
| **OpenCode** (`opencode.jsonc`) | `"rm -rf *": "deny"` — bloqueio de comandos destrutivos | `~/.config/opencode/opencode.jsonc` | ❌ Domínio diferente (comandos vs paths), mas mesmo padrão |
| **Cursor/VSCode** | `chat.tools.terminal.autoApprove` — allow list de comandos | `~/.config/Cursor/User/settings.json` | ❌ Apenas comandos seguros como `npm test`, `git --version` |
| **Claude Code** | `permissions.allow/deny/ask` — sistema de 3 categorias | Documentado na seção final do anotado | — |

> 🔍 **Descoberta:** O padrão "negar por lista + permitir seletivamente" aparece em 4 camadas diferentes do sistema: (1) DOTDIR_DENY paths, (2) OpenCode command deny, (3) Cursor/VSCode autoApprove, (4) Claude Code permissions. Cada camada opera em domínio diferente (filesystem x comandos shell), mas seguem a mesma arquitetura de segurança.

---

### Diretórios com permissão de escrita (linha 115)

```bash
DOTDIR_RW=(.claude .crush .codex .aider .config .cargo .cache .docker .nvm)
```

**O que faz:** Lista diretórios ocultos que, ao contrário dos demais, serão montados com permissão de **leitura e escrita**.

**Pra que serve:** **Permitir que as ferramentas funcionem corretamente.** Agentes de IA precisam salvar estado em `.claude`/`.crush`; `cargo` precisa baixar crates; `.config` e `.cache` são usados por dezenas de ferramentas. Sem escrita nesses diretórios, muitos comandos quebrariam.

### Mapeamento — DOTDIR_RW

| Diretório | Ferramenta | Por que rw | Mapeamento |
|-----------|-----------|-----------|------------|
| `.nvm` | Node Version Manager | Instalar/alternar versões Node | **Adicionado pelo mapper** — sistema usa nvm (Node v24.14.1 via nvm) |
| `.claude` | Claude Code | Estado de sessões | Ferramenta de IA |
| `.crush` | Crush AI | Estado de sessões | Ferramenta de IA |
| `.codex` | Codex CLI | Estado de sessões | Ferramenta de IA |
| `.aider` | Aider | Estado de sessões | Ferramenta de IA |
| `.config` | Genérico | Configurações de ferramentas | Montado rw com tmpfs overlay para subdiretórios sensíveis |
| `.cargo` | Cargo/Rust | Baixar crates, compilar | Gerenciador de pacotes |
| `.cache` | Genérico | Cache de ferramentas | Montado rw com tmpfs overlay para subdiretórios sensíveis |
| `.docker` | Docker CLI | Config, contextos | Container runtime |

---

### Funções auxiliares (linhas 118–128)

```bash
is_denied() {
    local name="$1"
    for d in "${DOTDIR_DENY[@]}"; do [[ "$name" == "$d" ]] && return 0; done
    return 1
}

is_rw() {
    local name="$1"
    for d in "${DOTDIR_RW[@]}"; do [[ "$name" == "$d" ]] && return 0; done
    return 1
}
```

**O que faz:** Duas funções que retornam verdadeiro/falso: `is_denied` checa se o nome está na lista de proibidos; `is_rw` checa se está na lista de leitura/escrita.

**Pra que serve:** **Separar a lógica de decisão do loop principal** — em vez de ter `if` complexo dentro do `for`, o código fica mais legível e reutilizável. Padrão comum em scripts shell para manter organização.

---

### Descoberta automática de dot-directories (linhas 130–145)

```bash
DOTFILE_MOUNTS=()
for entry in "$HOME"/.*; do
    [ -d "$entry" ] || continue
    name=$(basename "$entry")
    [[ "$name" == "." || "$name" == ".." ]] && continue
    is_denied "$name" && continue

    if is_rw "$name"; then
        DOTFILE_MOUNTS+=("--bind" "$entry" "$HOME/$name")
    else
        DOTFILE_MOUNTS+=("--ro-bind" "$entry" "$HOME/$name")
    fi
done
```

**O que faz:** Varre todos os diretórios ocultos na `$HOME` do usuário e decide como montar cada um: pula se for deny-list, monta rw se for rw-list, ou monta read-only.

**Pra que serve:** **Evitar ter que listar manualmente dezenas de diretórios.** Em vez de escrever `--ro-bind` pra cada diretório oculto, o script descobre tudo automaticamente. Isso é importante porque cada usuário tem um conjunto diferente de dotdirs (plugins do shell, configs de ferramentas, etc.). E ao usar as deny/rw lists, o script aplica as exceções corretas.

---

### Montagens explícitas de dotfiles (linhas 147–149)

```bash
[ -f "$HOME/.gitconfig" ] && DOTFILE_MOUNTS+=("--ro-bind" "$HOME/.gitconfig" "$HOME/.gitconfig")
[ -f "$HOME/.claude.json" ] && DOTFILE_MOUNTS+=("--bind" "$HOME/.claude.json" "$HOME/.claude.json")
```

**O que faz:** Monta **arquivos** específicos (`.gitconfig` e `.claude.json`), diferentemente do loop anterior que só pega diretórios.

**Pra que serve:** O loop só processa diretórios (`.claude/`, `.config/`), não arquivos soltos. Essas linhas garantem que **arquivos importantes** também entrem no sandbox — `.gitconfig` pra commits funcionarem (read-only), `.claude.json` pra config do Claude (read-write).

---

### Esconde subdiretórios sensíveis (linhas 151–161)

```bash
CONFIG_HIDE_MOUNTS=()
for denied in "${CONFIG_DENY[@]}"; do
    [ -d "$HOME/.config/$denied" ] && CONFIG_HIDE_MOUNTS+=("--tmpfs" "$HOME/.config/$denied")
done

CACHE_HIDE_MOUNTS=()
for denied in "${CACHE_DENY[@]}"; do
    [ -d "$HOME/.cache/$denied" ] && CACHE_HIDE_MOUNTS+=("--tmpfs" "$HOME/.cache/$denied")
done
```

**O que faz:** Para cada diretório sensível dentro de `~/.config` e `~/.cache`, cria uma montagem `--tmpfs` (vazia e volátil) que **sobrescreve** o diretório real.

**Pra que serve:** **Resolver o problema do "filho sensível dentro de pai permitido".** `~/.config` precisa ser rw para ferramentas funcionarem, mas `~/.config/Bitwarden` contém senhas. A solução é montar o pai com rw e depois **sobrescrever** o filho com um tmpfs vazio — dentro do sandbox, `~/.config/Bitwarden` existe mas está vazio.

---

### Overrides de `~/.local` (linhas 163–168)

```bash
LOCAL_OVERRIDES=()
[ -d "$HOME/.local/state" ] && LOCAL_OVERRIDES+=("--bind" "$HOME/.local/state" "$HOME/.local/state")
for rw_share in zoxide crush opencode atuin mise yarn flutter kotlin NuGet pipx ruby-advisory-db uv pnpm; do
    [ -d "$HOME/.local/share/$rw_share" ] && LOCAL_OVERRIDES+=("--bind" "$HOME/.local/share/$rw_share" "$HOME/.local/share/$rw_share")
done
```

**O que faz:** Monta subdiretórios específicos de `~/.local` com permissão de escrita, sobrescrevendo a montagem read-only do pai.

**Pra que serve:** `~/.local` é montado read-only no loop geral (proteção), mas ferramentas **precisam escrever** em seus próprios diretórios de dados (estado do zoxide, instalações do mise, cache do yarn, etc.). Esses overrides criam "janelas de escrita" dentro de uma área que é majoritariamente somente leitura.

| Subdiretório | Pra que serve dentro do sandbox |
|-------------|-------------------------------|
| `.local/state` | **Persistir estado** de ferramentas (ex.: zoxide, atuin) entre sessões |
| `.local/share/mise` | **Instalações de runtimes** — sem isso, `mise install node` falharia |
| `.local/share/yarn` | **Cache de pacotes** — yarn baixa pacotes npm aqui |
| `.local/share/pipx` | **Pacotes Python** instalados globalmente via pipx |
| `.local/share/uv` | **Cache do UV** — sem isso toda instalação pip baixaria do zero |
| `.local/share/crush/opencode` | **Dados dos agentes de IA** — configurações, histórico, sessões |
| `.local/share/pnpm` | **Store do pnpm** — pacotes npm gerenciados pelo pnpm |

> 🔄 **Adicionado pelo Security Layer Mapper:** `pnpm` — estava no script real mas ausente do anotado.

---

### Esconde subdiretórios sensíveis em `~/.local/share` (pós-linha 117, adicionado pelo Security Layer Mapper)

```bash
LOCAL_HIDE=()
for denied in keyrings kwalletd; do
    [ -d "$HOME/.local/share/$denied" ] && LOCAL_HIDE+=("--tmpfs" "$HOME/.local/share/$denied")
done
```

**O que faz:** Para cada diretório sensível em `~/.local/share`, cria uma montagem `--tmpfs` (vazia e volátil) que **sobrescreve** o diretório real.

**Pra que serve:** **Proteger cofres de senhas que ficam dentro de `~/.local/share`.** O GNOME Keyring (`keyrings/`) e o KDE Wallet (`kwalletd/`) armazenam senhas em texto plano (dentro de arquivos criptografados que podem ser acessados). Como `.local/share` é montado read-only por padrão, os arquivos ainda seriam legíveis. O tmpfs overlay os torna invisíveis.

### Mapeamento — LOCAL_HIDE

| Item | Sistema | Risco | Descoberto pelo Security Layer Mapper |
|------|---------|-------|---------------------------------------|
| `keyrings` | GNOME Keyring | 🔴 Alto — `login.keyring`, `user.keystore` com senhas | **GAP:** Não estava em nenhuma lista de negação |
| `kwalletd` | KDE Wallet | 🔴 Alto — `kdewallet.kwl` com senhas | **GAP:** Não estava em nenhuma lista de negação |

---

### Dispositivos GPU (linhas 170–174)

```bash
GPU_MOUNTS=()
for dev in /dev/nvidia* /dev/dri; do
    [ -e "$dev" ] && GPU_MOUNTS+=("--dev-bind" "$dev" "$dev")
done
```

**O que faz:** Monta dispositivos de GPU (NVIDIA e/ou DRM Intel/AMD) dentro do sandbox.

**Pra que serve:** **Permitir aceleração gráfica.** Ferramentas como Cursor, VS Code, e navegadores baseados em Chromium **precisam** de GPU para renderizar a interface. Sem esses dispositivos, a interface ficaria lerda ou nem abriria.

---

### Docker socket (linhas 176–178)

```bash
DOCKER_MOUNT=()
[ -S /var/run/docker.sock ] && DOCKER_MOUNT+=("--bind" "/var/run/docker.sock" "/var/run/docker.sock")
```

**O que faz:** Monta o socket do Docker dentro do sandbox.

**Pra que serve:** **Permitir que a IA execute comandos Docker** (docker run, docker compose, etc.). É opcional e intencionalmente desativado se o socket não existir.

> **⚠️⚠️⚠️ RISCO CRÍTICO:** Montar o socket Docker **anula parcialmente o isolamento do jail** — o socket Docker dá acesso root ao host. Um container malicioso iniciado pela IA pode escapar do sandbox via `--pid=host`, `--privileged`, ou montando volumes do host. O Docker é uma ferramenta de isolamento, mas o **socket Docker em si é uma porta de escape**.

### Mapeamento — Docker Socket

| Item | Estado no sistema |
|------|------------------|
| **Docker instalado?** | ✅ Sim (v29.5.2) |
| **Socket existe?** | ✅ `/var/run/docker.sock` |
| **docker.sock no jail?** | Sim — bind mounted (DOCKER_MOUNT ativo) |
| **Plugins Docker** | 13 plugins: `docker-ai`, `docker-sandbox`, `docker-mcp`, `docker-scout`, `docker-debug`, etc. |
| **Config Docker** | `~/.docker/config.json` com `credsStore: "desktop"` |
| **Config Desktop** | `~/.config/Docker Desktop/persisted-state.json` com Docker Agent, MCP Toolkit |

> ⚡ **Recomendação:** Se a IA não precisar de Docker, remova o bloco DOCKER_MOUNT ou torne-o opt-in via flag `--docker`. O script atual monta automaticamente se o socket existir.

---

### Memória compartilhada (linhas 180–182)

```bash
SHM_MOUNT=()
[ -d /dev/shm ] && SHM_MOUNT+=("--dev-bind" "/dev/shm" "/dev/shm")
```

**O que faz:** Monta `/dev/shm` (memória compartilhada) dentro do sandbox.

**Pra que serve:** **Evitar crashes em apps que usam memória compartilhada.** Chromium e derivados (Cursor, VS Code, navegadores) usam `/dev/shm` para comunicação entre processos. Se não existir ou for muito pequeno, o app pode travar ou nem iniciar.

---

### Passthrough de display (X11 + Wayland) — linhas 184–201

```bash
DISPLAY_MOUNTS=()
DISPLAY_ENV=()

# X11 / XWayland socket
[ -d /tmp/.X11-unix ] && DISPLAY_MOUNTS+=("--bind" "/tmp/.X11-unix" "/tmp/.X11-unix")
[ -n "${DISPLAY:-}" ] && DISPLAY_ENV+=("--setenv" "DISPLAY" "$DISPLAY")
[ -n "${XAUTHORITY:-}" ] && {
    DISPLAY_MOUNTS+=("--ro-bind" "$XAUTHORITY" "$XAUTHORITY")
    DISPLAY_ENV+=("--setenv" "XAUTHORITY" "$XAUTHORITY")
}

# Wayland socket
if [ -n "${XDG_RUNTIME_DIR:-}" ] && [ -d "$XDG_RUNTIME_DIR" ]; then
    DISPLAY_MOUNTS+=("--bind" "$XDG_RUNTIME_DIR" "$XDG_RUNTIME_DIR")
    DISPLAY_ENV+=("--setenv" "XDG_RUNTIME_DIR" "$XDG_RUNTIME_DIR")
    [ -n "${WAYLAND_DISPLAY:-}" ] && DISPLAY_ENV+=("--setenv" "WAYLAND_DISPLAY" "$WAYLAND_DISPLAY")
fi
```

**O que faz:** Monta os sockets de comunicação com o servidor gráfico (X11 ou Wayland) e repassa as variáveis de ambiente necessárias.

**Pra que serve:** **Permitir que a IA abra janelas gráficas.** Sem isso, ferramentas com interface (Cursor, VS Code, navegadores) não conseguiriam renderizar nada na tela. O jail precisa abrir uma exceção no isolamento visual para que o usuário veja o que a IA está fazendo.

---

### Montagem e execução do bwrap (linhas 203–240)

```bash
echo "Jail Active: $PROJECT_DIR"

bwrap \
  --ro-bind /usr /usr \
  --ro-bind /bin /bin \
  --ro-bind /lib /lib \
  --ro-bind /lib64 /lib64 \
  --ro-bind /etc /etc \
  --ro-bind "$TEMP_HOSTS" /etc/hosts \
  --ro-bind /opt /opt \
  --ro-bind /sbin /sbin \
  --ro-bind /sys /sys \
  --dev /dev \
  "${GPU_MOUNTS[@]}" \
  "${SHM_MOUNT[@]}" \
  --proc /proc \
  --tmpfs /tmp \
  --tmpfs /run \
  "${DOCKER_MOUNT[@]}" \
  "${DISPLAY_MOUNTS[@]}" \
  --tmpfs "$HOME" \
  "${DOTFILE_MOUNTS[@]}" \
  "${CONFIG_HIDE_MOUNTS[@]}" \
  "${CACHE_HIDE_MOUNTS[@]}" \
  "${LOCAL_OVERRIDES[@]}" \
  "${LOCAL_HIDE[@]}" \
  "${EXTRA_MOUNTS[@]}" \
  --bind "$PROJECT_DIR" "$PROJECT_DIR" \
  --chdir "$PROJECT_DIR" \
  --die-with-parent \
  --unshare-pid \
  --unshare-uts \
  --unshare-ipc \
  --hostname "ai-sandbox" \
  "${DISPLAY_ENV[@]}" \
  --setenv PS1 "(jail) \w \$ " \
  --setenv _ZO_DOCTOR 0 \
  bash -c "$MISE_INIT && $NVM_INIT && ${*:-bash}"
```

#### Tabela completa de flags:

| Flag | O que faz | Pra que serve |
|------|-----------|--------------|
| `--ro-bind /usr /usr` | Monta `/usr` como read-only | **Dar acesso a programas e bibliotecas** sem risco de modificação |
| `--ro-bind /bin /bin` | Monta `/bin` como read-only | **Acesso a binários essenciais** — bind direto resolve symlink `/bin → /usr/bin` em sistemas usrmerge |
| `--ro-bind /lib /lib` | Monta `/lib` read-only | **Bibliotecas compartilhadas** — bind direto resolve symlink `/lib → /usr/lib` |
| `--ro-bind /lib64 /lib64` | Monta `/lib64` read-only | **Bibliotecas 64-bit** — bind direto resolve symlink `/lib64 → /usr/lib` |
| `--ro-bind /sbin /sbin` | Monta `/sbin` read-only | **Binários administrativos** — bind direto resolve symlink `/sbin → /usr/sbin` |
| `--ro-bind /etc /etc` | Monta `/etc` read-only | **Configs de sistema** (resolv.conf, ca-certificates, etc.) — a IA precisa ler mas não modificar |
| `--ro-bind "$TEMP_HOSTS" /etc/hosts` | Sobrescreve `/etc/hosts` com o temporário | **Bloquear/redirecionar DNS** da IA para domínios específicos |
| `--ro-bind /opt /opt` | Monta `/opt` read-only | **Acesso a programas instalados em /opt** (como SDKs manuais) |
| `--ro-bind /sys /sys` | Monta `/sys` read-only | **Informações do hardware/kernel** — necessário para alguns drivers e ferramentas |
| `--dev /dev` | Cria `/dev` mínimo | **Dispositivos essenciais** (null, random, tty, urandom) |
| `"${GPU_MOUNTS[@]}"` | Monta dispositivos GPU | **Aceleração gráfica** para interfaces baseadas em Chromium |
| `"${SHM_MOUNT[@]}"` | Monta `/dev/shm` | **Memória compartilhada** para Chromium e apps similares |
| `--proc /proc` | Monta `/proc` isolado | **Comandos de sistema funcionarem** sem expor processos do host |
| `--tmpfs /tmp` | Cria `/tmp` vazio e volátil | **Arquivos temporários** — tudo é descartado ao sair do sandbox |
| `--tmpfs /run` | Cria `/run` vazio e volátil | **Runtime files** — usado por systemd, Docker, etc. |
| `"${DOCKER_MOUNT[@]}"` | Monta socket Docker (opcional) | **Permitir Docker** dentro do sandbox |
| `"${DISPLAY_MOUNTS[@]}"` | Monta sockets gráficos | **Interface gráfica** — a IA precisa mostrar janelas |
| `--tmpfs "$HOME"` | Cria `$HOME` vazia | **Partir de um ambiente limpo** — nada do seu home é exposto por padrão |
| `"${DOTFILE_MOUNTS[@]}"` | Monta dotfiles descobertos | **Reintroduzir seletivamente** os configs que a IA precisa |
| `"${CONFIG_HIDE_MOUNTS[@]}"` | Sobrescreve configs sensíveis | **Esconder senhas/navegadores** dentro de `~/.config` |
| `"${CACHE_HIDE_MOUNTS[@]}"` | Sobrescreve caches sensíveis | **Esconder dados de navegador/app** dentro de `~/.cache` |
| `"${LOCAL_OVERRIDES[@]}"` | Subdiretórios de `.local` rw | **Permitir escrita seletiva** em tooling específico |
| `"${LOCAL_HIDE[@]}"` | Sobrescreve keyrings/kwalletd com tmpfs | **Esconder cofres de senhas** (GNOME Keyring, KDE Wallet) dentro de `.local/share` |
| `"${EXTRA_MOUNTS[@]}"` | Montagens extras do `--map` | **Customização do usuário** sem mexer no script |
| `--bind "$PROJECT_DIR" "$PROJECT_DIR"` | Monta workspace rw | **Único lugar onde a IA pode escrever** — o projeto atual |
| `--chdir "$PROJECT_DIR"` | Entra no diretório ao iniciar | **Já começar no projeto certo** — evita `cd` manual |
| `--die-with-parent` | Mata sandbox se pai morrer | **Evitar processos zumbis** — se o terminal fechar, o jail morre junto |
| `--unshare-pid` | Isola namespace de PID | **IA não vê processos do host** — não sabe o que mais está rodando |
| `--unshare-uts` | Isola hostname | **Mudar hostname dentro do sandbox** sem afetar o sistema |
| `--unshare-ipc` | Isola IPC | **Impedir comunicação entre processos** do sandbox com o host |
| `--hostname "ai-sandbox"` | Define hostname no sandbox | **Identificar visualmente** que está dentro do jail |
| `"${DISPLAY_ENV[@]}"` | Define variáveis de display | **Conectar ao servidor gráfico** para abrir janelas |
| `--setenv PS1 "(jail) \w \$ "` | Muda o prompt do shell | **Lembrete visual** de que está no sandbox |
| `--setenv _ZO_DOCTOR 0` | Desativa verificação do zoxide | **Evitar warnings** chatos do zoxide |
| `bash -c "$MISE_INIT && $NVM_INIT && ${*:-bash}"` | Executa comando final | **Rodar o agente de IA** com mise + nvm (runtime) já configurados |

---

### Modo de usar (linhas 244–254)

```bash
chmod +x ~/.local/bin/ai-jail
~/.local/bin/ai-jail crush
~/.local/bin/ai-jail bash  # shell interativo no jail
~/.local/bin/ai-jail --map /extra/path claude
```

---

## Configuração de permissões do Claude Code (linhas 258–369)

```json
{
  "permissions": {
    "allow": [
      "Bash(git add *)",
      "Bash(ls *)",
      "Bash(grep *)",
      ...
    ],
    "deny": [
      "Bash(rm -rf *)",
      "Bash(sudo *)",
      ...
    ],
    "ask": [
      "Bash(git push *)",
      "Bash(docker run *)",
      ...
    ],
    "defaultMode": "acceptEdits"
  }
}
```

**O que faz:** Define três categorias de permissão: comandos que o Claude executa sem perguntar (`allow`), comandos bloqueados (`deny`), e comandos que exigem confirmação (`ask`).

**Pra que serve:** **Duas camadas de segurança, não uma.** O jail protege o **sistema operacional** (a IA não consegue escrever fora do projeto). As permissões do Claude protegem contra a **própria IA** (impedem que o modelo sequer tente certos comandos). Um complementa o outro:

| Camada | Protege contra | Exemplo |
|--------|---------------|---------|
| **Jail (bwrap)** | Danos ao sistema | `rm -rf ~` falha porque a home não é montada |
| **Permissões Claude** | Decisões ruins do modelo | Claude nem tenta `sudo rm -rf /` porque está no `deny` |

### Mapeamento — OpenCode ↔ Claude Code ↔ Cursor/VSCode Permissions

Durante a auditoria, descobriu-se que **três ferramentas** no sistema implementam o mesmo padrão de segurança "allow/deny/ask" para controlar agentes de IA:

#### Tabela Comparativa

| Aspecto | OpenCode | Claude Code | Cursor/VSCode |
|---------|----------|-------------|---------------|
| **Arquivo** | `~/.config/opencode/opencode.jsonc` | `~/.claude.json` (documentado no script, NÃO existe no sistema) | `~/.config/Cursor/User/settings.json` |
| **Sincronizado?** | Arquivo standalone (não em dotfiles) | ❌ Não existe no sistema | Symlink para `dotfiles/data/` |
| **Allow** | `"git add *": "allow"`, `"edit": "allow"`, etc. | `"Bash(git add *)": "allow"` | `chat.tools.terminal.autoApprove` |
| **Deny** | `"rm -rf *": "deny"`, `"sudo *": "deny"` | `"Bash(rm -rf *)": "deny"` | Comandos não listados são implicitamente negados |
| **Ask** | `"docker run *": "ask"`, `"chmod *": "ask"` | `"Bash(docker run *)": "ask"` | Padrão para comandos não aprovados |
| **Default** | `"*": "ask"` (tudo precisa aprovação) | `"defaultMode": "acceptEdits"` | Ask |

#### Mapeamento do Conceito

```
┌─────────────────────────────────────────────────────────────┐
│                    TRÊS CAMADAS DE SEGURANÇA                │
├─────────────────┬─────────────────────┬─────────────────────┤
│  AI Jail        │  OpenCode           │  Claude/Cursor      │
│  (bwrap)        │  (opencode.jsonc)   │  (permissions)      │
├─────────────────┼─────────────────────┼─────────────────────┤
│  Protege:       │  Protege:           │  Protege:           │
│  Filesystem     │  Comandos shell     │  Comandos shell     │
│  (bind mounts)  │  (allow/deny/ask)   │  (allow/deny/ask)   │
├─────────────────┼─────────────────────┼─────────────────────┤
│  Nega por:      │  Nega por:          │  Nega por:          │
│  DOTDIR_DENY    │  "deny" array       │  "deny" + autoApprove│
│  (paths)        │  (glob patterns)    │  (regex patterns)   │
└─────────────────┴─────────────────────┴─────────────────────┘
```

#### Insights da Auditoria

1. **OpenCode é a ferramenta mais alinhada** com o conceito de Claude Code permissions — ambas têm allow/deny/ask explícitos. A diferença principal é que OpenCode usa glob patterns e Claude Code usa `Bash(cmd *)` patterns.

2. **Cursor/VSCode usa uma abordagem mais limitada** — `autoApprove` só permite comandos específicos por regex, sem uma lista de deny explícita.

3. **Gap:** O `~/.claude.json` não existe no sistema. Se o usuário começar a usar Claude Code, precisará criar as permissões.

4. **OpenCode não está versionado em dotfiles** — `~/.config/opencode/opencode.jsonc` é standalone. Considere adicionar ao repositório de dotfiles.

---

## Apêndice: Security Layer Mapping — Síntese

### Metodologia

O Security Layer Mapper percorreu cada seção do AI-Jail-Anotado.md, extraiu o conceito de segurança, e perguntou: *"existe alguma ferramenta, aplicação ou configuração no sistema do usuário que lida com conceito semelhante?"*

### Resultados Consolidados

#### GAPs Encontrados e Corrigidos

| # | Seção | Gap | Impacto | Ação |
|---|-------|-----|---------|------|
| 1 | Deny-lists | `.ollama` não estava bloqueado (contém chave `id_ed25519`) | 🔴 Alto | Adicionado ao DOTDIR_DENY |
| 2 | Deny-lists | `keyrings/` (GNOME) e `kwalletd/` (KDE) expostos em `.local/share` | 🔴 Alto | Adicionado LOCAL_HIDE com tmpfs |
| 3 | Runtime | Sistema usa nvm, não mise — Node/npm não funcionavam | 🟡 Médio | Adicionado NVM_INIT + `.nvm` em DOTDIR_RW |
| 4 | LOCAL_OVERRIDES | `pnpm` estava no script real mas ausente do anotado | 🟢 Baixo | Sincronizado (sync) |
| 5 | Deny-lists | Anotado desatualizado vs script real (faltavam `.ssh`, `.steam`, `.pki`, `.var`, `.android`, `.gemini`, `google-chrome`, `Code`, etc.) | 🟡 Médio | Sincronizado (sync) |
| 6 | Claude Code permissions | `~/.claude.json` não existe no sistema | 🟢 Info | Documentado |
| 7 | Docker socket | Montagem automática sem opt-in | 🟡 Médio | Documentação do risco ampliada |

#### Mapeamentos Sem Ação Necessária

| Seção | Conceito | Ferramentas similares | Decisão |
|-------|----------|----------------------|---------|
| 1. bwrap flags | Namespace isolation | Docker, Flatpak, Podman | Docker/Flatpak instalados mas não usados como sandbox alternativo |
| 4. Trap EXIT | Cleanup handler | Outros scripts em ~/.local/bin/ | Apenas ai-jail cria temp files |
| 6. DNS blocking | /etc/hosts blocking | dnsmasq, NextDNS, Pi-hole | Nenhum presente no sistema |
| 16. GPU mounts | GPU passthrough | /dev/dri only (sem NVIDIA) | Script já trata corretamente |
| 19. Display | X11 + Wayland | VNC, Xpra, x11vnc | Nenhum presente no sistema |

#### Padrões de Segurança Recorrentes

O exercício revelou **4 camadas independentes de segurança** no sistema que seguem o mesmo padrão arquitetural:

| Camada | Domínio | Mecanismo | Ferramenta |
|--------|---------|-----------|-----------|
| L4 — Filesystem | Acesso a paths | DOTDIR_DENY + tmpfs overlay | AI Jail (bwrap) |
| L3 — Comandos shell | Execução de comandos | allow/deny/ask + glob patterns | OpenCode |
| L2 — Comandos shell | Execução de comandos | allow/deny/ask + regex | Claude Code |
| L1 — Comandos shell | Auto-aprovação seletiva | autoApprove (regex allowlist) | Cursor/VSCode |

> **Conclusão:** O sistema do usuário tem uma **arquitetura de segurança em profundidade (defense-in-depth)** completa, com 4 camadas que se complementam. A camada L4 (AI Jail) é a única que opera no nível de filesystem — as demais operam no nível de comandos shell. Um bypass de uma camada ainda seria barrado pela próxima.
