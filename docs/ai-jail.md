# 🔒 ai-jail (Segurança)

> Bubblewrap sandbox para AI coding agents — isola o filesystem e a rede para executar agentes de IA com segurança no Linux.

Este documento detalha a configuração atual do `ai-jail`, um script customizado que usa o bubblewrap (`bwrap`) para criar ambientes isolados para agentes de IA como Claude Code, OpenCode e outros.

## 🛠 Tech Stack
- **Sandbox**: [bubblewrap](https://github.com/containers/bubblewrap) 0.11.0
- **Namespace isolation**: Linux namespaces (PID, UTS, IPC)
- **Runtime detection**: Mise (opcional) e NVM (opcional)

## ⚡ Configuração Atual (`~/.local/bin/ai-jail`)

O script descobre automaticamente dot-directories em `$HOME` e os monta dentro do sandbox com base em três listas de controle:

### Deny-lists (diretórios NUNCA montados)
```bash
DOTDIR_DENY=(.gnupg .aws .mozilla .ssh .steam .pki .var .ollama)
CONFIG_DENY=(BraveSoftware Bitwarden google-chrome discord gh Pinokio obsidian)
CACHE_DENY=(BraveSoftware chromium spotify nvidia google-chrome)
```

### Read-write (diretórios com permissão de escrita)
```bash
DOTDIR_RW=(.claude .crush .codex .aider .config .cargo .cache .docker .nvm)
```

### Montagens explícitas de dotfiles
```bash
[ -f "$HOME/.gitconfig" ] && ... --ro-bind ...
[ -f "$HOME/.claude.json" ] && ... --bind ...
```

## 🗺 Estrutura de Arquivos
- `~/.local/bin/ai-jail`: Script principal do sandbox (versionado em `data/.local/bin/ai-jail`)
- `/usr/bin/bwrap`: Binário bubblewrap (dependência externa, não versionada)

## 🔒 Segurança
- **Arquivos versionados**: `data/.local/bin/ai-jail` — contém apenas lógica de mounts e deny-lists por nome
- **Arquivos excluídos**: Nenhum — o script não contém secrets, apenas referências nominais a diretórios
- **Guardrails aplicados**:
  - `SECURITY NOTE` no topo: arquivo versionado, não adicionar secrets
  - `DANGER ZONE` no parsing de `--map`/`--rw-map`: paths fornecidos pelo usuário entram no sandbox
  - `DANGER ZONE` no `MISE_INIT` eval: execução de código do mise binário
  - `DANGER ZONE` no `NVM_INIT`: sourcing do nvm.sh dentro do sandbox
  - `DANGER ZONE` nas deny-lists: definem toda a boundary de segurança do sandbox
  - `SECURITY NOTE` no Docker socket: acesso total ao daemon Docker do host

## 🚀 Como instalar

1. **Instale o bubblewrap**:
   ```bash
   sudo apt install bubblewrap
   ```
2. **O script já está versionado** em `data/.local/bin/ai-jail` com guardrails de segurança
3. **Ative o symlink**:
   ```bash
   ./dotfiles-menu.sh
   # Selecione ai-jail ou execute install-dotfiles.sh
   ```
4. **Uso básico**:
   ```bash
   ai-jail bash              # Shell isolado no diretório atual
   ai-jail claude            # Executa Claude Code no sandbox
   ai-jail --map /path extra_command  # Monta path extra como ro
   ai-jail --rw-map /path extra_command  # Monta path extra como rw
   ```

## 🧠 Skill relacionada

Existe uma skill `ai-jail-security-layer-mapper` em `~/.agents/skills/ai-jail-security-layer-mapper/` que mapeia cada seção de segurança do script e verifica se outras ferramentas no sistema deveriam ser configuradas da mesma forma.

---

*Este documento foi gerado durante o onboarding do ai-jail nos dotfiles.*
