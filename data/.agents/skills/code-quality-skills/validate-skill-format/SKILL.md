---
name: "validate-skill-format"
description: "Varre todos os SKILL.md do repositório e valida o frontmatter: L1 exatamente '---', L2 'name: \\"...\\"' com aspas duplas, L3 começa com 'description: \\"', e linha anterior ao '---' de fechamento termina com '\\"'. Nunca modifica arquivos — apenas reporta problemas e sugere correções."
---

# validate-skill-format

Script de validação de frontmatter para arquivos `SKILL.md`.

## Quando usar

- Quando quiser verificar se todos os SKILL.md estão no formato padronizado
- Antes de commitar mudanças em skills
- Para identificar skills com frontmatter fora do padrão

## Como usar

O agente deve executar:

```bash
python3 skills/code-quality-skills/validate-skill-format/validate_skills.py
```

O script varre recursivamente toda a árvore `skills/` em busca de `SKILL.md`, valida cada um e exibe:

- ✅ para arquivos válidos
- ❌ para arquivos com erro (com descrição do problema)
- 💡 sugestões de correção

## Regras validadas

| # | Regra | Imutável |
|---|-------|----------|
| 1 | L1: `---` | Sim |
| 2 | L2: `name: "..."` (com aspas duplas) | Sim |
| 3 | L3: começa com `description: "` | Sim |
| 4 | Existe 2º `---` delimitando o fim do frontmatter | Sim |
| 5 | Linha anterior ao 2º `---` termina com `"` | Sim |
| 6 | Nome da skill (após `name:`) não vazio | Sim |
| 7 | (sugestão) Nome corresponde ao nome da pasta | Não |

## Exit codes

- `0`: todos os SKILL.md válidos
- `1`: pelo menos um SKILL.md com erro
