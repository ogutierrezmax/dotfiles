---
title: 'CRUD de Skills no Skills GUI'
type: feature
ticket: ''
created: '2026-11-10'
status: built
baseline_revision: 'ee9e3f7123aa63d7a11e732f5b78c0001d919ccd'
route: 'full'
route_source: 'auto'
risk: 'medium'
review: 'quick'
review_source: 'pinned'
lenses_ran: ['quick']
review_loop_iteration: 0
context:
  - _bmad-output/initiative-skills-crud/ux-skills-crud/DESIGN.md
  - _bmad-output/initiative-skills-crud/ux-skills-crud/EXPERIENCE.md
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** O Skills GUI atualmente apenas visualiza skills e edita metadados em `skills-catalog.json`. Não é possível criar novas skills, editar as instruções do `SKILL.md` diretamente ou excluir skills do sistema de arquivos sem recorrer ao terminal ou operações manuais de arquivo.

**Approach:** Implementar comandos Tauri no backend Rust (`create_skill`, `save_skill_content`, `delete_skill`) com validação estrita de caminhos canônicos e sincronização atômica com o catálogo, integrando no frontend TypeScript uma experiência fluida: modal de criação com validação em tempo real de slug (`Alt+N`), editor inline de `SKILL.md` no drawer lateral (`Ctrl+S`), e modal de perigo com confirmação digitada para exclusão definitiva.

## Boundaries & Constraints

**Always:**
- Validação de caminho canônico: todas as operações de escrita/deleção devem ocorrer estritamente dentro de `data/.agents/skills/`.
- Consistência de catálogo: criar uma skill adiciona sua entrada no `skills-catalog.json`; deletar uma skill remove sua entrada do `skills-catalog.json`.
- Exclusão segura: a exclusão definitiva exige fricção positiva com digitação exata do nome da skill na confirmação modal.
- Formato inicial do `SKILL.md`: conter frontmatter YAML válido com `name` e `description`.
- Verificação: `cargo check` no Rust e `npx tsc --noEmit` no TypeScript devem passar com zero erros.

**Never:**
- Nunca permitir path traversal (`..`, caminhos absolutos, barras) em nomes de skills.
- Nunca deletar diretórios fora do acervo de skills.
- Nunca aplicar bridge automaticamente em background sem notificação ao usuário.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|---|---|---|---|
| Criar skill com dados válidos | Name: `my-skill`, Description: `Desc`, Category: `devops`, Tools: `["claude", "cursor"]` | Cria pasta `data/.agents/skills/my-skill/`, gera `SKILL.md`, insere no catálogo, fecha modal, abre drawer da nova skill | Se nome já existir: retorna erro `skill já existe no acervo` antes de tocar no disco |
| Criar com nome inválido / colisão | Name: `My Skill!` ou nome existente | Validação visual instantânea no modal; backend rejeita se enviado | Erro exibido no formulário ou toast em vermelho |
| Salvar edição de SKILL.md | Name: `my-skill`, Content: texto Markdown | Grava `data/.agents/skills/my-skill/SKILL.md`, atualiza `updated_at` no catálogo, exibe toast de confirmação | Se I/O falhar, exibe toast de erro |
| Exclusão com confirmação digitada | Name: `my-skill`, Confirmação: `my-skill` | Remove diretório no disco, remove entrada no catálogo, fecha drawer e modal, atualiza grid, exibe toast com ação de bridge | Botão de exclusão permanece inativo até digitação exata |
| Tentativa de path traversal | Name: `../../etc` | Rejeitado por validação canônica de `valid_skill_dir` | Retorna erro seguro sem tocar em arquivos |

</frozen-after-approval>

## Code Map

- `apps/skills-gui/src-tauri/src/main.rs` -- Backend Tauri: implementar comandos `create_skill`, `save_skill_content`, `delete_skill` com verificação de segurança canônica e registro em `tauri::generate_handler!`.
- `apps/skills-gui/ui/index.html` -- Estrutura HTML: inserir botão `+ Nova Skill` na toolbar.
- `apps/skills-gui/ui/styles.css` -- Estilos CSS: estilizar botão primário, modal de criação, textarea de edição monoespaçada, abas de visualização/edição e diálogo de perigo.
- `apps/skills-gui/src/app.ts` -- Frontend TypeScript: adicionar modal de criação (`Alt+N`), abas de visualização/edição no drawer (`Ctrl+S`), modal de perigo para exclusão e handlers de IPC.

## Tasks & Acceptance

**Execution:**
- [ ] `apps/skills-gui/src-tauri/src/main.rs` -- Adicionar comandos Tauri `create_skill`, `save_skill_content`, `delete_skill` com validações de segurança e registro no handler -- Fornece API de backend para operações de filesystem e catálogo.
- [ ] `apps/skills-gui/ui/index.html` -- Adicionar botão `+ Nova Skill` na toolbar principal -- Permite disparo rápido do fluxo de criação.
- [ ] `apps/skills-gui/ui/styles.css` -- Adicionar estilos para botão de criação, abas de alternância do drawer, editor monospace e modal de perigo -- Aplica a identidade visual de DESIGN.md.
- [ ] `apps/skills-gui/src/app.ts` -- Implementar lógica de criação com validação de slug em tempo real, editor de SKILL.md no drawer e modal de confirmação digitada para exclusão -- Implementa as jornadas especificadas em EXPERIENCE.md.

**Acceptance Criteria:**
- Given o usuário no Skills GUI, when clica em `+ Nova Skill` ou pressiona `Alt+N`, then o modal de criação abre com foco no campo de nome e validação em tempo real de slug.
- Given nome válido e descrição informada, when aciona "Criar", then a pasta `data/.agents/skills/<name>/` e o arquivo `SKILL.md` são criados no disco, registrados no catálogo e o drawer abre na nova skill.
- Given uma skill aberta no drawer, when alternada para o modo "Editar" e pressionado `Ctrl+S` após alteração, then o arquivo `SKILL.md` no disco é atualizado e toast confirma o salvamento.
- Given uma skill selecionada, when acionado "Excluir Skill" no drawer, then modal de perigo exige digitar o nome da skill antes de habilitar a exclusão.
- Given o nome digitado corretamente, when confirmado, then a pasta da skill é excluída do disco, removida do catálogo e a grid é atualizada.

## Design Notes

- Estrutura do `SKILL.md` padrão gerado:
  ```markdown
  ---
  name: {name}
  description: {description}
  ---

  # {name}

  {description}

  ## Overview

  Descreva aqui a finalidade desta skill.

  ## Instructions

  Instruções para o agente...
  ```
- Validação de slug: `^[a-z0-9][a-z0-9._-]*$`, sem caracteres proibidos ou espaços.

## Verification

**Commands:**
- `cargo check --manifest-path apps/skills-gui/src-tauri/Cargo.toml` -- expected: compilação do Rust sem erros de sintaxe ou tipos.
- `npx tsc --noEmit -p apps/skills-gui/tsconfig.json` -- expected: verificação de tipos TypeScript limpa.


## Review Triage Log

- `high` -- patch: `src-tauri/src/main.rs:18` `is_valid_skill_slug` rejeitava skills existentes com `_` inicial (`_knowledge-manager`); corrigido para aceitar `_` como caractere inicial e proibir finalização em ponto/espaço.
- `medium` -- patch: `src/app.ts:477` evento `Ctrl+S` no editor sem `stopPropagation()` gerava disparo concorrente; corrigido adicionando `ev.stopPropagation()`.
- `medium` -- patch: `src/app.ts:354, 523` edições de `SKILL.md` eram perdidas se usuário alternasse para aba 'view' antes de salvar ou fechar; corrigido checando dirty state independente do modo da aba e salvando no `saveDrawer`.
- `medium` -- patch: `src-tauri/src/main.rs:97` descrição com quebras de linha ou caracteres especiais formatava YAML inválido; sanitizado colapsando linhas e serializando via `serde_json::to_string`.
- `low` -- patch: `src-tauri/src/main.rs:181` `delete_skill` seguia symlink no canonicalize; corrigido tratando symlinks via `symlink_metadata` e `fs::remove_file`.
- `low` -- patch: `ui/index.html:61` e `src/app.ts:840` modais não possuíam `role="dialog"` e `aria-modal="true"`; atributos adicionados para acessibilidade.
- `low` -- patch: `ui/styles.css:426, 437` opacidade de backdrop e classes de largura máxima (`.modal-create: 540px`, `.modal-delete: 480px`) ausentes; estilos adicionados conforme DESIGN.md.
- `low` -- patch: `src/app.ts:434` cabeçalho do editor no drawer sem botão `↗ Abrir no Editor`; botão adicionado e conectado ao `openPath`.
- `low` -- patch: `src/app.ts:794` submissão de criação não desabilitava inputs do formulário; adicionada desabilitação de todos os campos durante IPC.
- `low` -- patch: `src-tauri/src/main.rs:21` e `src/app.ts:734` compatibilidade Windows para slugs terminados em ponto; rejeição adicionada na validação.
- `low` -- patch: `src-tauri/src/main.rs:144` `save_skill_content` não usava `.entry().or_default()` no catálogo; corrigido para sincronização consistente.
