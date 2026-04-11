# Skill: feature-classification

## Purpose

Classificar a feature em **work_type**, **change_type**, **test_strategy** e **regression_risk** para decidir se exige Cover and Modify e preencher a seção "Impacto em legado e estratégia de testes" do artefato. A classificação alimenta gates do KFlow (ex.: não chamar o script de gravação se for legado e a seção estiver vazia).

## When to use

No **K1 (k1-refinement)**, após o skill de **clarification** e antes (ou em sequência com) **user-story** e **acceptance-criteria**. A entrada é o Clarified summary; opcionalmente a user story ou objetivo já produzidos.

## How to apply

1. **Input:** Clarified summary (e user story/objetivo se existir).
2. **Passo 1 — Heurística:** Aplicar palavras-chave e contexto: refatorar, legado, existente, módulo X, integração com Y, código novo, nova API, etc. Propor classificação inicial (work_type, change_type, test_strategy, regression_risk).
3. **Passo 2 — Desambiguação:** Se ambíguo, fazer até uma pergunta objetiva ao usuário: *"A feature altera ou depende de código existente já em produção?"* (greenfield vs brownfield/hybrid).
4. **Passo 3:** Preencher **work_type**, **change_type**, **test_strategy**, **regression_risk**, **requires_cover_and_modify** conforme a taxonomia (ver documento abaixo). Lembrete: `requires_cover_and_modify = true` sse work_type ∈ { brownfield, hybrid }.
5. **Passo 4:** Retornar o output no formato do contrato (YAML ou markdown), pronto para colar na seção "Impacto em legado e estratégia de testes" quando `requires_cover_and_modify = true`.

## Output

Bloco estruturado (YAML ou markdown) com todos os campos obrigatórios do contrato: **work_type**, **change_type**, **test_strategy**, **regression_risk**, **requires_cover_and_modify**. Opcional: **areas_affected**, **rationale**. Formato definido em [.devtool/devDocs/feature-classification-taxonomy.md](../../../.devtool/devDocs/feature-classification-taxonomy.md#contrato-de-output-da-skill). Quando `requires_cover_and_modify = true`, incluir subseções sugeridas: Áreas/módulos afetados, Estratégia de testes (antes de refatorar), Risco.

Exemplo (brownfield):

```yaml
work_type: brownfield
change_type: refactor
test_strategy: cover-and-modify
regression_risk: high
requires_cover_and_modify: true
areas_affected: [módulo de pagamento]
rationale: Refatoração do fluxo existente sem testes.
```

## NEVER invoke when

A feature já tiver **classificação explícita** no corpo do artefato ou no frontmatter (work_type, requires_cover_and_modify, ou seção "Impacto em legado e estratégia de testes" preenchida). Nesse caso, reutilizar a classificação existente.

## Referência

Taxonomia e contrato: [.devtool/devDocs/feature-classification-taxonomy.md](../../../.devtool/devDocs/feature-classification-taxonomy.md). KFlow: [.devtool/devDocs/kflow-documentacao-completa.md](../../../.devtool/devDocs/kflow-documentacao-completa.md).
