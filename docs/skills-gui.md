# 🧩 Skills GUI

> Gerenciador desktop (Tauri 2) do acervo de agent skills dos dotfiles: organização por categoria/tags, saúde da
> estrutura flat, exposição por ferramenta (bridge) e abertura no editor.

![Status](https://img.shields.io/badge/status-active-brightgreen)
![Tauri 2](https://img.shields.io/badge/desktop-Tauri_2-orange)
![Catalog](https://img.shields.io/badge/metadata-JSON-blue)
![License](https://img.shields.io/badge/license-MIT-green)

---

## 🎯 Por que o Skills GUI Existe?

O acervo `~/.agents/skills` é **flat**: 82 diretórios, cada um com seu `SKILL.md`. Antes, a organização vivia em
15 *bundles* (diretórios sem `SKILL.md` agrupando sub-skills), o que escondia 68 skills das ferramentas que
escaneiam apenas um nível. O `scripts/flatten-agent-skills.sh` achatou o acervo; a organização passou para um
**catálogo versionado** de metadados.

O Skills GUI é a interface desse catálogo:

1. **Organiza** — categoria, tags, favoritas e notas por skill, sem tocar nos arquivos.
2. **Expõe** — escolhe em quais ferramentas a skill aparece via symlink (bridge).
3. **Audita** — estrutura flat, cobertura do catálogo, nomes divergentes e symlinks quebrados.
4. **Opera** — roda `flatten-agent-skills.sh --check` e o bridge (`--doctor`, `--dry-run`, apply) com um clique.
5. **Arquiva** — move skills inativas para a pasta de arquivo do app (`apps/skills-gui/archive/`) com metadados preservados, sem gerar órfãs no acervo ativo.

> [!IMPORTANT]
> O catálogo é a **fonte de verdade da organização**, não do conteúdo. Renomear uma skill continua sendo uma
> operação de `git mv` + ajuste do frontmatter — o catálogo usa o **nome do diretório** como id estável.

---

## 🗺️ Arquitetura

```mermaid
graph TD
    subgraph Repositório Dotfiles
        CAT["apps/skills-gui/catalog/skills-catalog.json<br/>(categoria/tags/tools)"]
        SCHEMA["skills-catalog.schema.json"]
        FLAT["data/.agents/skills/<skill>/SKILL.md<br/>(82 skills flat)"]
        BRIDGE["scripts/install-agent-skills-bridge.sh"]
        FLATTEN["scripts/flatten-agent-skills.sh"]
    end

    subgraph App Tauri 2
        UI["ui/index.html + src/app.ts"]
        RS["src-tauri/src/main.rs<br/>(comandos Rust)"]
    end

    subgraph Host
        TOOLS["~/.claude/skills, ~/.cursor/skills,<br/>~/.agent/skills, ~/.copilot/skills,<br/>~/.config/devin/skills, ~/.gemini/skills"]
    end

    UI -->|invoke| RS
    RS -->|lê/grava| CAT
    RS -->|lê| FLAT
    RS -->|executa| FLATTEN
    RS -->|executa| BRIDGE
    BRIDGE -->|symlinks| TOOLS
    CAT -.->|--from-catalog| BRIDGE
```

---

## ⚡ Quick Start

```bash
# Abrir a interface (compila na primeira vez)
skills-gui

# Menu principal
dotfiles-menu.sh   # digite: skills gui

# Recompilar o binário release
skills-gui --build
```

A janela abre com o acervo carregado do repositório resolvido por `DOTFILES_REPO_ROOT` (o launcher exporta) ou
por busca ascendente a partir do diretório atual/executável.

---

## 🗂️ Catálogo (`skills-catalog.json`)

Contrato em `apps/skills-gui/catalog/skills-catalog.schema.json`. Forma:

```json
{
  "version": 1,
  "updatedAt": "2026-11-10T15:00:00Z",
  "categories": [
    { "id": "devops", "label": "DevOps", "order": 70 }
  ],
  "skills": {
    "agents-md": {
      "category": "ai-config",
      "tags": ["agents", "config"],
      "tools": null,
      "favorite": false,
      "notes": ""
    }
  }
}
```

| Campo | Significado |
|---|---|
| chave de `skills` | nome do diretório em `~/.agents/skills` (id estável) |
| `category` | id de uma entrada em `categories`; `null` = **Sem categoria** |
| `tags` | lista livre, normalizada (trim, ordenada, sem duplicatas) |
| `tools` | ferramentas que recebem o symlink via bridge; `null` = **todas**; `[]` = nenhuma |
| `favorite` | estrela na UI |
| `notes` | anotação interna (não vai para o `SKILL.md`) |

Ferramentas válidas: `claude`, `devin`, `antigravity`, `copilot`, `cursor`, `gemini`.

### Categorias

As 16 categorias iniciais vieram dos bundles achatados (`ai-config`, `ai-ecosystem`, `code-quality`, `curso`,
`cursor-ide`, `debugging`, `devops`, `dotfiles`, `implementation`, `k-flow`, `k1-refinement`, `product`,
`tech-domain`, `testing`, `utilities`) + `uncategorized`. A UI cria, edita e exclui categorias; excluir move as
skills para **Sem categoria** (nunca apaga skill).

---

## 🖥️ Interface

- **Sidebar** — visões (todas, favoritas, sem categoria, nome divergente), categorias com contagem, tags e
  ferramentas (exposição via bridge).
- **Busca** — nome, nome de exibição, descrição, notas, categoria e tags.
- **Cards** — descrição, categoria, tags, ferramentas, favoritar, tamanho/contagem de arquivos e data.
- **Seleção múltipla** — mover várias skills para uma categoria de uma vez.
- **Drawer** — edita categoria/tags/tools/favorita/notas, mostra o `SKILL.md` e abre a pasta ou o arquivo no
  editor padrão (`xdg-open`).
- **Saúde** — mesmas checagens do `flatten-agent-skills.sh --check`, em painel.
- **Bridge** — `doctor`, `dry-run` e apply com saída completa em modal.

### Ordenação e filtros

`Nome A→Z`, `Mais recentes`, `Categoria`, `Mais arquivos`. O filtro de ferramenta considera `tools: null` como
"todas" — e a UI avisa que **leitura nativa** (OpenCode, Codex, Cursor, Copilot) não é afetada.

---

## 🔗 Integração com o bridge

O botão **Aplicar bridge** executa:

```bash
scripts/install-agent-skills-bridge.sh --from-catalog
```

Com `--from-catalog`, as specs `*`/`**` do `config/agent-skills-bridge.list` passam a respeitar o campo `tools`
do catálogo; links gerenciados fora do conjunto permitido são removidos. Specs explícitas (`<nome>`) vencem o
catálogo. Sem a flag, o bridge continua expondo todas as skills (compatibilidade).

Detalhamento de guardrails, manifest do Antigravity e diagnóstico em [`docs/agent-skills-bridge.md`](agent-skills-bridge.md).

---

## 📦 Arquivamento de Skills

Skills inativas, obsoletas ou em desuso podem ser arquivadas para não poluírem o acervo ativo ou o bridge de ferramentas de IA:

- **Localização física**: As pastas arquivadas ficam em `apps/skills-gui/archive/<skill>/` (dentro da pasta do app).
- **Metadados preservados**: Os metadados (categoria, tags, tools, favorita, notas e timestamp) são isolados em `apps/skills-gui/archive/archive-catalog.json`. Isso evita que o catálogo ativo (`skills-catalog.json`) acuse skills órfãs no `flatten-agent-skills.sh --check`.
- **Visão dedicada**: A sidebar do app exibe o filtro `📦 Arquivadas` com a contagem total de skills arquivadas.
- **Restauração**: Pelo Drawer da skill ou na barra de ações em lote, o usuário pode clicar em `↩️ Desarquivar Skill` para retornar a pasta para `data/.agents/skills/` e reintegrar os metadados ao catálogo principal.
- **Exclusão Definitiva**: Skills arquivadas podem ser excluídas permanentemente do disco caso não sejam mais necessárias.

---

## 🔒 Segurança

- O backend só escreve **no catálogo** e na pasta controlada de arquivo (`apps/skills-gui/archive/`); comandos de deleção exigem validação canônica estrita contra path traversal.
- `archive_skill` e `unarchive_skill` validam slugs estritos (`^[a-z0-9][a-z0-9._-]*$`) e rejeitam colisões de nomes.
- `save_skill_meta` valida que o diretório existe e tem `SKILL.md` (rejeita `/`, `\`, `..`).
- `save_category` restringe o id a `a-z`, `0-9` e `-`.
- `open_path` só abre caminhos canônicos dentro do repositório ou do acervo.
- Escrita dos catálogos (ativo e arquivo) é atômica (arquivo temporário + rename).
- O apply do bridge mantém os guardrails do script: backup em `.bkp/`, nunca `rm -rf`, nunca toca diretórios
  reais divergentes.

---

## 🧪 Validação

```bash
# Estrutura flat + cobertura do catálogo (exit 1 se houver pendência)
scripts/flatten-agent-skills.sh --check

# Bridge filtrado pelo catálogo (exit 1 se houver drift)
scripts/install-agent-skills-bridge.sh --doctor --from-catalog

# Diagnóstico sem abrir a janela (útil quando a grade aparece vazia)
apps/skills-gui/src-tauri/target/release/skills-gui --print-repo
apps/skills-gui/src-tauri/target/release/skills-gui --print-skills

# Typecheck do frontend
tsc -p apps/skills-gui/tsconfig.json

# Build do binário
skills-gui --build
```

### Resolução do repositório

O backend procura a raiz nesta ordem: `DOTFILES_REPO_ROOT` (exportado pelo launcher) → diretório
atual e seus pais → diretório do executável e seus pais → `~/dotfiles`. Um diretório só é aceito se
tiver `data/.agents/skills` **e** um dos marcadores do repo (`apps/skills-gui/catalog` ou
`config/agent-skills-bridge.list` + `scripts/install-agent-skills-bridge.sh`) — sem essa checagem,
`apps/skills-gui` (que também tem `catalog/`) seria confundido com a raiz.

Se a grade aparecer vazia, o app mostra um painel com o caminho tentado; `--print-repo` imprime
`repo_root`, `skills_dir` e `catalog` sem abrir a janela.

---

## 📁 Arquivos envolvidos

| Caminho | Papel |
|---|---|
| `apps/skills-gui/catalog/skills-catalog.json` | catálogo versionado (fonte da organização) |
| `apps/skills-gui/catalog/skills-catalog.schema.json` | contrato JSON Schema |
| `apps/skills-gui/archive/` | pasta física do arquivo de skills inativas/obsoletas |
| `apps/skills-gui/archive/archive-catalog.json` | catálogo de metadados das skills arquivadas |
| `apps/skills-gui/src-tauri/src/main.rs` | comandos Tauri (catálogo, arquivo, saúde, scripts) |
| `apps/skills-gui/src/app.ts` | frontend TypeScript (compila para `ui/app.js`) |
| `apps/skills-gui/ui/` | HTML/CSS/JS carregados pela janela |
| `data/.local/bin/skills-gui` | launcher (compila o frontend e o binário quando necessário) |
| `data/.local/share/applications/skills-gui.desktop` | entrada no menu de aplicações |
| `scripts/flatten-agent-skills.sh` | migração/checagem da estrutura flat |
| `scripts/install-agent-skills-bridge.sh` | bridge (`--from-catalog`, `--doctor`, `--dry-run`) |
| `config/agent-skills-bridge.list` | escopo por ferramenta |
