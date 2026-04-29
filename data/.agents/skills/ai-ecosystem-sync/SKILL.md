---
name: ai-ecosystem-sync
description: Sincroniza regras e skills entre Cursor, Antigravity e Claude Code. Mantém CLAUDE.md e .claude/ em dia.
---

# Skill: AI Ecosystem Sync

Esta skill é responsável por manter a sincronização de regras, habilidades (skills) e configurações entre as ferramentas Cursor, Antigravity e Claude Code.

## Capacidades

1. **Sincronização de Regras**: Converte regras do Cursor (`.cursor/rules/*.mdc`) para o formato do Claude Code (`CLAUDE.md`).
2. **Mapeamento de Skills**: Garante que as habilidades locais e globais do Antigravity estejam disponíveis como ferramentas no Claude Code via links simbólicos em `.claude/skills/`.
3. **Manutenção de Estrutura**: Verifica e restaura a árvore de diretórios `.claude/` necessária para a interoperabilidade.

## Quando usar

- Após modificar qualquer arquivo em `.cursor/rules/`.
- Após adicionar ou editar uma skill na pasta `skills/`.
- Ao configurar o projeto em um novo ambiente para garantir que o Claude Code funcione corretamente.
- Quando notar que o Claude Code não está seguindo as regras definidas no Cursor.

## Instruções de Execução

Para sincronizar o ecossistema, você deve executar o script de orquestração:

```bash
./scripts/sync-ai.sh
```

### O que o script faz:
1. **Limpeza de Frontmatter**: Remove metadados YAML específicos do Cursor para que o Claude Code leia o Markdown puramente.
2. **Consolidação**: Reúne todas as regras granulares em um único arquivo `CLAUDE.md` (padrão do Claude Code).
3. **Linking**:
   - `.cursor/rules/` -> `.claude/rules/shared`
   - `skills/` (local) -> `.claude/skills/local`
   - `~/.gemini/antigravity/skills/` (global) -> `.claude/skills/antigravity`

## Melhores Práticas

- **Fonte Única**: Sempre edite as regras na pasta `.cursor/rules/`. Evite editar o `CLAUDE.md` diretamente, pois ele será sobrescrito.
- **Skills Globais**: Mantenha habilidades genéricas na pasta global do Antigravity e habilidades específicas do projeto na pasta `skills/` da raiz.
