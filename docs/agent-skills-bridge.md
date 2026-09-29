# 🧩 Agent Skills Bridge

> Symlinks por-skill: cada ferramenta de IA enxerga as **79** skills do acervo central `~/.agents/skills` sem manter cópias duplicadas.

Este documento detalha o **bridge de skills de IA** — mecanismo que elimina cópias duplicadas de skills entre ferramentas
(Claude Code, Devin, Copilot, Antigravity, Cursor, etc.) apontando os diretórios de skills de cada ferramenta para a **fonte única**
versionada neste repositório.

## 🛠 Tech Stack
- **Acervo central**: `~/.agents/skills` (symlink → `dotfiles/data/.agents/skills`)
- **Configuração**: `config/agent-skills-bridge.list`
- **Script**: `scripts/install-agent-skills-bridge.sh`
- **Manifest**: `~/.gemini/config/skills.json` (gerado, **não** versionado)
- **Tipo de link**: symlink **por skill** (não por diretório inteiro) — preserva skills específicas de cada ferramenta
  (ex.: `pinokio` no Cursor) e segue o suporte oficial a symlinks por skill das ferramentas.

## 🗺 Por que existe

O kit MCP+skill do Context7 foi instalado em 9 ferramentas, criando **cópias reais duplicadas** da mesma skill em cada
diretório (`~/.claude/skills`, `~/.cursor/skills`, ...). Atualizar uma skill exigia propagar a mudança em N lugares.
O bridge resolve isso com uma única fonte.

O acervo tem duas formas:

| Forma | O que é | Quantas |
|---|---|---|
| **leaf** | diretório com `SKILL.md` direto em `~/.agents/skills/<nome>/` | 11 |
| **bundle** | diretório **sem** `SKILL.md`, agrupando sub-skills em `<bundle>/<skill>/SKILL.md` | 15 bundles / 68 sub-skills |

Só o **OpenCode** (e o Codex) leem `~/.agents/skills` **recursivamente**. Todas as outras ferramentas procuram
`<root>/<skill>/SKILL.md` — **um nível só** — então as 68 sub-skills de bundle simplesmente não existiam para elas.
É esse o motivo do wildcard `**` (achatar por basename), e não do symlink em si.

### Quem lê `~/.agents/skills` nativamente (sem bridge)
- **OpenCode** e **Codex** — leem recursivamente, compartilham o acervo inteiro. Nenhuma entrada no config.
- **VS Code (Copilot)** e **GitHub Copilot CLI** — leem `~/.agents/skills`, **mas só as 11 leaves** (1 nível).
  Por isso também existe a entrada `copilot|**` em `~/.copilot/skills`.
- **Cursor** e **Gemini CLI** — leem `~/.agents/skills` (1 nível); entradas no config são espelhos **opcionais**.

### Quem precisa de bridge
- **Claude Code** — só lê `~/.claude/skills`.
- **Devin** — só lê `~/.config/devin/skills`.
- **Copilot (VS Code / CLI)** — além de `~/.copilot/skills`, o core do VS Code resolve symlink de filho
  (`fileService.resolve`), mas o scanner interno da extensão usa verificação estrita de tipo e **pula** symlink.
  A rota do manifest não existe aqui; se uma skill não aparecer, o sintoma é esse (ver *Validação*).
- **Antigravity 2.0** (CLI `agy` + IDE) — bug conhecido (google-antigravity/antigravity-cli#103): não lê
  `~/.agents/skills`. O bridge cobre os 3 caminhos reconhecidos **e** escreve o manifest oficial.

## ⚙️ Configuração: `config/agent-skills-bridge.list`

Formato: `<ferramenta>|<spec>` — o `spec` pode ser:

| Spec | Efeito |
|---|---|
| `*` | todas as **leaf skills** de topo (diretórios com `SKILL.md` direto) |
| `**` | **todas** as skills em qualquer profundidade, achatadas por basename (o diretório da skill vira o nome) |
| `<nome>` | skill leaf específica (ex.: `context7-mcp`) |
| `<bundle>/<nome>` | sub-skill dentro de um bundle (ex.: `tech-domain-skills/tauri-gmail-oauth`, usada pelo Cursor) |
| `@manifest` | gera/atualiza o manifest de customização da ferramenta (`TOOL_MANIFEST` no script) |

```text
claude|**
devin|**
antigravity|**
antigravity|@manifest
copilot|**
cursor|tech-domain-skills/tauri-gmail-oauth
```

O mapa de ferramentas → diretórios fica no próprio script (`TOOL_DIRS`, separados por `:`), porque depende do
`$HOME` de cada máquina.

## 📄 Manifest do Antigravity (`skills.json`)

O spec `@manifest` gera `~/.gemini/config/skills.json`:

```json
{
  "entries": [
    { "path": "~/.agents/skills" },
    { "path": "~/.agents/skills/ai-config-skills" }
  ]
}
```

- **1 entry para a raiz** (as 11 leaves) + **1 por bundle** — o Antigravity escaneia **um nível por entry**,
  então um bundle só é coberto por uma entry própria.
- Caminhos `~/...` são resolvidos pelo próprio Antigravity (*home-relative*) → portátil entre máquinas.
- **Gerado, não versionado**: evita índice desatualizado no git, e o path configurado no Antigravity tem
  precedência sobre auto-discovery.
- Sobrescrita só ocorre com **backup datado** em `.bkp/`.
- Redundância proposital: o bridge per-skill em `~/.gemini/config/skills` **e** o manifest cobrem os dois
  scanners (o de symlink e o de manifest).

## 🚀 Como funciona

```bash
# Sob demanda (menu)
dotfiles-menu.sh   # digite: skills        → reconstrói
dotfiles-menu.sh   # digite: skills doctor → diagnóstico read-only

# Direto
scripts/install-agent-skills-bridge.sh              # aplica
scripts/install-agent-skills-bridge.sh --dry-run    # mostra o que faria
scripts/install-agent-skills-bridge.sh --doctor     # read-only, exit 1 se houver drift
```

**Automação em máquina nova**: `scripts/install-dotfiles.sh` chama o bridge automaticamente após linkar os dotfiles
(cria o symlink `~/.agents` → `data/.agents` e depois reconstrói todos os bridges).

O script é **idempotente** e **declarativo** (o estado desejado vem do acervo + do config) e segue este estado por destino:

| Estado do destino | Ação |
|---|---|
| Symlink que resolve para a skill do acervo | nada (ok) |
| Symlink errado/quebrado | relinka |
| Diretório real **idêntico** ao acervo | move para `.bkp/` datado + cria symlink (conversão) |
| Diretório real **diferente** do acervo | 🔒 alerta, conta como drift e **pula** (nunca destrói trabalho) |
| Symlink órfão (alvo removido do acervo) | remove o link (quebrado confunde a ferramenta) |
| Diretório da ferramenta **é** o acervo central (alias) | normaliza: remove **só o link** e recria os links por-skill |
| Manifest `.json` existente e diferente | backup datado em `.bkp/` + regenera |

## 🩺 `--doctor` (read-only)

Imprime, por ferramenta/root, quantas skills estão visíveis vs. esperadas, o manifest em dia ou não, e os avisos
de higiene. **Exit 1 se houver drift** (inclui skill pulada por divergência — precisa de decisão humana).

```
TOOL         ROOT                                      ESPERADO VISÍVEIS  ESTADO
claude       ~/.claude/skills                                 79        78  DRIFT
copilot      ~/.copilot/skills                                79        79  ok
```

## 🔒 Guardrails (SECURITY NOTE)

- **Nunca** usa `rm -rf`; só remove symlinks gerenciados que apontam para dentro de `~/.agents/skills`.
- Diretórios reais são **sempre movidos para `.bkp/` antes** de virarem symlink (nada é apagado sem backup).
- O alias que **é** o acervo central tem a fonte preservada: remove-se apenas o link.
- Links são **absolutos** via `$HOME/.agents/...` → funcionam em qualquer máquina onde o repo for clonado.
- Skills fora da configuração (ex.: `plantuml` no Claude, skills da Google Cloud em `~/.gemini/config/skills`)
  **nunca** são tocadas.
- Colisão de basename entre bundles → **as duas** skills são ignoradas com aviso (o script nunca escolhe por conta).
- Nomes fora de `^[a-z0-9][a-z0-9._-]*$` (prefixo `@`/`_`) são apenas **avisados** — nunca renomeados.

## ⚠️ Sintomas conhecidos

| Sintoma | Causa | O que fazer |
|---|---|---|
| `SKIP: <dir> difere do acervo` | existe uma cópia **real** e divergente da mesma skill (ex.: `~/.claude/skills/pinokio`, versão antiga em inglês) | decidir conscientemente: mover a local para `.bkp/` e deixar o bridge linkar, ou remover a entrada do acervo |
| Skill não aparece no Copilot (VS Code) | o scanner interno da extensão **pula symlink** (o core resolve) | recarregar a janela; se persistir, apontar `chat.agentSkillsLocations` para o path **real** do acervo |
| Skill não aparece no `agy` | frontmatter inválido (YAML quebrado ou a sequência de três hifens dentro do texto) | rodar a validação de frontmatter do acervo |
| `~/.agent/skills` vazio | só era escrito com `*` (11 leaves) | resolvido pelo `**` — 79 |

## 📁 Arquivos envolvidos
- `config/agent-skills-bridge.list`: escopo das ferramentas (o que bridar).
- `scripts/install-agent-skills-bridge.sh`: lógica do bridge (idempotente, com backup e salvaguardas) + `--doctor`.
- `scripts/install-dotfiles.sh`: dispara o bridge ao final da instalação.
- `dotfiles-menu.sh` + `scripts/dotfiles-menu-commands.sh` + `scripts/dotfiles-menu-ui.sh`: comandos `skills` e `skills doctor`.
- `data/.agents/skills/`: o acervo central versionado (fonte única).

## 🧪 Validação

```bash
# Diagnóstico completo (read-only, exit 1 se houver drift)
scripts/install-agent-skills-bridge.sh --doctor

# Sem links quebrados nos diretórios gerenciados
find ~/.claude/skills ~/.copilot/skills ~/.gemini/config/skills \
     -maxdepth 1 -xtype l 2>/dev/null

# Amostra dos targets
readlink ~/.claude/skills/context7-mcp   # → ~/.agents/skills/context7-mcp
readlink ~/.copilot/skills/dotfiles-manager  # → ~/.agents/skills/dotfiles-skills/dotfiles-manager

# Quantas skills o Antigravity enxerga (saída local, sem chamar o modelo)
agy --print "/skills" | cut -f1 | sort -u
```

No VS Code: `Developer: Reload Window` e abrir o catálogo de skills do Copilot
(ou Output → Log (Copilot), procurando `computeSkillDiscoveryInfo`).
Skills duplicadas entre `~/.agents/skills` e `~/.copilot/skills` são esperadas: o VS Code deduplica por nome
(`Skipping duplicate agent skill name`).
