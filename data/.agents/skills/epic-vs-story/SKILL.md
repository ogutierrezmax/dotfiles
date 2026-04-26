---
name: epic-vs-story
description: Classifica uma funcionalidade clarificada como épico (muito grande para
  uma sprint, deve ser decomposto) ou história de usuário (entregável único, pronto
  para a skill user-story). Use no K1 após a clarificação (Passo 1) e antes da user-story
  (Passo 3). A entrada é o resumo clarificado. A saída é a granularidade (epic | user_story
  | ambiguous) e a suggested_action para o fluxo k1.
---

# Skill: epic-vs-story

## Purpose

Decidir se uma feature clarificada é **épico** (grande demais para uma sprint, deve ser decomposto) ou **user story** (entregável único, pode seguir para a skill user-story). O resultado orienta o k1-refinement: épico → não chamar user-story para o todo (decompor ou salvar como épico); user_story → seguir para o Passo 3 (user-story).

## When to use

No **K1 (k1-refinement)**, após o **Passo 1** (clarification / request-clarifier) e **antes** do **Passo 3** (skill [user-story](../user-story/SKILL.md)). A entrada obrigatória é o **Clarified summary**; opcionalmente a user story ou objetivo já produzidos.

## How to apply

1. **Input:** Clarified summary (obrigatório). Opcional: user story ou objetivo já escritos.
2. **Heurísticas — épico:** Múltiplos atores ou múltiplos objetivos; expressões como "sistema de X", "módulo completo de Y"; escopo que abrange várias entregas ou fluxos distintos; algo que claramente não cabe em uma única sprint.
3. **Heurísticas — user story:** Um ator, um objetivo, um benefício; entregável único; cabível em uma sprint (INVEST: Small, Estimable); um need por story.
4. **Classificar:** Atribuir `granularity: epic | user_story | ambiguous`.
5. **Se ambiguous:** Incluir no output a sugestão para o k1: *"Re-invocar request-clarifier com pergunta focada: épico (decompor depois) ou user story (entrega única)?"*
6. **Preencher suggested_action (opcional):** `decompose_first` (é épico), `proceed_to_user_story` (é user story), `ask_user` (ambiguous).
7. **Retornar** o output no formato do contrato (YAML ou markdown), pronto para o k1 decidir o próximo passo.

## Output

Contrato com campos obrigatórios e opcionais. Formato pronto para o k1: se **epic** → não chamar user-story para o todo (sugerir decomposição ou salvar como épico); se **user_story** → seguir para Passo 3 (user-story); se **ambiguous** → usar sugestão do campo ou re-invocar request-clarifier.

**Campos obrigatórios:**

| Campo | Tipo | Valores |
|-------|------|---------|
| `granularity` | string | `epic` \| `user_story` \| `ambiguous` |
| `suggested_action` | string | `decompose_first` \| `proceed_to_user_story` \| `ask_user` |

**Campos opcionais:** `rationale` (breve justificativa da classificação).

Exemplo (user story):

```yaml
granularity: user_story
suggested_action: proceed_to_user_story
rationale: Um ator, um objetivo (notificação por e-mail ao concluir compra), entregável único.
```

Exemplo (épico):

```yaml
granularity: epic
suggested_action: decompose_first
rationale: "Sistema de checkout" abrange pagamento, carrinho, fretes; múltiplas entregas.
```

Exemplo (ambiguous):

```yaml
granularity: ambiguous
suggested_action: ask_user
rationale: Escopo pode ser só relatório ou todo o módulo de analytics.
```

Quando `granularity: ambiguous`, incluir no output (ou em rationale) a sugestão: *Re-invocar request-clarifier com pergunta focada: épico (decompor depois) ou user story (entrega única)?*

## NEVER invoke when

Já existir no artefato ou no frontmatter **classificação explícita** de granularidade (epic vs user_story). Nesse caso reutilizar a classificação existente e não aplicar a skill.

## Referência

Definições de épico e user story: [Glossário — Hierarquia de decomposição](../../../.devtool/devDocs/Hierarquia%20de%20decomposição%20e%20ciclo%20de%20vida%20do%20desenvolvimento%20de%20software/Glossário.md). Fluxo K1 e skill user-story: [user-story](../user-story/SKILL.md). Classificação de feature (work_type, etc.): [feature-classification](../feature-classification/SKILL.md).
