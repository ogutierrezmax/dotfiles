---
type: ux
title: "UX Specification: CRUD de Skills no Skills GUI"
design: DESIGN.md
experience: EXPERIENCE.md
updated: 2026-11-10
status: final
---

# UX: CRUD de Skills no Skills GUI

Este documento consolida a especificação de UX e design de interação para a funcionalidade de **CRUD de Skills** no aplicativo desktop **Skills GUI** (Tauri 2).

## Documentos Principais

- **[DESIGN.md](DESIGN.md)**: Especificação de identidade visual, tokens Catppuccin Mocha, componentes de interface, tipografia e diretrizes de estilo.
- **[EXPERIENCE.md](EXPERIENCE.md)**: Arquitetura da informação, comportamento dos componentes, jornadas de usuário (criação, edição e exclusão), estados de erro/sucesso, atalhos de teclado e acessibilidade.

## Resumo dos Componentes Desenvolvidos

1. **Toolbar e Gatilho de Criação**:
   - Botão `+ Nova Skill` com atalho global `Alt+N` / `Ctrl+N`.
2. **Modal de Criação**:
   - Input de slug com validação em tempo real de kebab-case e checagem de colisão.
   - Campos de descrição, categoria e ferramentas do bridge pré-selecionadas.
   - Geração de template padrão de `SKILL.md`.
3. **Editor In-App no Drawer**:
   - Alternância entre `Visualizar` e `Editar` o arquivo `SKILL.md` inline.
   - Atalho `Ctrl+S` para gravação rápida no filesystem.
4. **Zona de Perigo e Exclusão Segura**:
   - Modal com barreira de confirmação exigindo digitação do nome da skill.
   - Limpeza coordenada de diretório no filesystem, entrada no `skills-catalog.json` e notificação com ação de atualizar o bridge.
