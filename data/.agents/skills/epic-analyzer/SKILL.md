---
name: epic-analyzer
description: Analisa épicos de Kanban para determinar se estão prontos para avançar
  para a próxima fase ou precisam de ajustes. Use esta skill sempre que o usuário
  mencionar "analisar épico", "épico pronto", "revisar épico", "avaliar card", "ready
  for next phase", "análise de épico", "verificar épico", ou colar o conteúdo de um
  épico/card Kanban pedindo uma avaliação. Também deve ser ativada quando o usuário
  perguntar "esse épico está pronto?", "o que falta no meu épico?", "pode revisar
  meu épico?" ou qualquer variação. Aplica-se a épicos em qualquer ferramenta (Jira,
  Linear, Trello, Notion, planilha, texto livre).
---

# Skill: Analisador de Épicos Kanban

## Objetivo
Avaliar a qualidade e completude de um épico Kanban e emitir um veredicto claro:
✅ **Pronto para avançar** ou 🔴 **Precisa de ajustes** — com justificativas e ações concretas.

---

## Passo 1 — Identificar o contexto

Antes de analisar, verifique o que o usuário forneceu:

| Forneceu | Ação |
|---|---|
| Texto do épico (título + descrição + critérios) | Analise diretamente |
| Lista de histórias/tasks do épico | Analise + infira o épico pai |
| Ambos | Análise completa |
| Só um título ou ideia vaga | Peça mais detalhes antes de prosseguir |

Se o usuário mencionou a **fase atual** (ex: "está em Refinamento"), use isso. Se não mencionou, tente inferir pelo conteúdo e pergunte apenas se for crítico para o veredicto.

---

## Passo 2 — Dimensões de análise

Avalie o épico em **6 dimensões**. Cada uma recebe um status:
- ✅ OK
- ⚠️ Parcial (existe mas pode melhorar)
- ❌ Ausente/Bloqueante

### 1. Clareza do Problema / Objetivo
- Existe uma declaração clara do problema ou oportunidade?
- O "por quê" está explícito?
- Há uma métrica de sucesso ou resultado esperado?

### 2. Critérios de Aceite (Definition of Ready / Done)
- Existem critérios de aceite listados?
- São testáveis e objetivos (não vagos como "melhorar experiência")?
- Cobrem os cenários principais, incluindo erros/edge cases?

### 3. Escopo e Histórias Filhas
- O épico está decomposto em histórias/tasks filhas?
- O escopo está delimitado (o que está IN e o que está OUT)?
- As histórias são independentes e estimáveis?

### 4. Estimativa e Esforço
- Existe alguma estimativa de esforço (story points, t-shirt size, dias)?
- O tamanho do épico é razoável para uma entrega (não é um "mega-épico")?

### 5. Dependências e Bloqueios
- Há dependências de outros times, sistemas ou épicos identificadas?
- Existe algum bloqueio em aberto?
- As dependências têm donos e prazos?

### 6. Stakeholders e Aprovações
- O épico tem um dono/responsável definido?
- Stakeholders relevantes foram envolvidos?
- Existe alguma aprovação necessária antes de avançar?

---

## Passo 3 — Veredicto por fase

Use a fase atual do épico para calibrar o veredicto:

### Backlog → Refinamento
Mínimo exigido: Dimensões 1 e 2 como ✅ ou ⚠️.

### Refinamento → Em Progresso / Execução
Mínimo exigido: Dimensões 1, 2 e 3 como ✅. Dimensões 4 e 5 como ✅ ou ⚠️.

### Em Progresso → Revisão / Validação
Mínimo exigido: Todas as dimensões ✅ ou ⚠️. Nenhuma ❌.

### Revisão → Concluído
Mínimo exigido: Dimensões 1, 2 e 6 como ✅. Critérios de aceite verificados.

> Se a fase não for informada, use o critério de Refinamento → Em Progresso como padrão.

---

## Passo 4 — Formato de saída

Sempre responda neste formato:

```
## 🔍 Análise do Épico: [Nome do Épico]

**Fase atual:** [identificada ou "não informada"]
**Próxima fase:** [inferida]

---

### Avaliação por Dimensão

| Dimensão | Status | Observação |
|---|---|---|
| Clareza do Problema | ✅/⚠️/❌ | Breve comentário |
| Critérios de Aceite | ✅/⚠️/❌ | Breve comentário |
| Escopo e Histórias | ✅/⚠️/❌ | Breve comentário |
| Estimativa | ✅/⚠️/❌ | Breve comentário |
| Dependências | ✅/⚠️/❌ | Breve comentário |
| Stakeholders | ✅/⚠️/❌ | Breve comentário |

---

### Veredicto

[✅ PRONTO PARA AVANÇAR] ou [🔴 PRECISA DE AJUSTES]

**Justificativa:** [2-3 frases explicando o veredicto]

---

### Ações Recomendadas

[Se PRONTO]: liste 1-3 sugestões de melhoria não-bloqueantes (nice to have).
[Se PRECISA DE AJUSTES]: liste os itens obrigatórios a corrigir, em ordem de prioridade, com exemplos concretos do que escrever.
```

---

## Boas práticas ao analisar

- **Seja direto**: o veredicto deve ser claro, não ambíguo.
- **Dê exemplos**: ao apontar algo ausente, mostre como ficaria se estivesse correto.
- **Priorize bloqueantes**: separe o que é impeditivo do que é sugestão.
- **Respeite o contexto**: um épico de discovery tem critérios diferentes de um épico de execução técnica.
- **Não invente informações**: se algo não está no épico, marque como ❌ e explique o que falta — não assuma que existe.
- **Linguagem**: responda no mesmo idioma do épico analisado (português se o épico for em PT, inglês se for em EN).