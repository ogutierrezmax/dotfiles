# Template Unificado de Desenvolvimento de Produto

Use este documento como base para organizar a documentacao de produto de ponta a ponta em qualquer projeto.

---

## 1) Contexto e proposito

- **Produto**: `<NOME_DO_PRODUTO>`
- **Resumo em 1 frase**: `<RESUMO_DO_PRODUTO>`
- **Publico-alvo principal**: `<PUBLICO_ALVO>`
- **Objetivo deste template**: unificar navegacao dos artefatos + governanca do processo por etapas.

---

## 2) Mapa de pastas recomendado (`docs/product/`)

```text
docs/
└── product/
    ├── index.md
    ├── product-vision/
    │   ├── README.md
    │   └── 01-vision-statement.md
    ├── market-research/
    │   ├── README.md
    │   ├── 01-problem-statement.md
    │   ├── 02-user-personas.md
    │   ├── 03-competitive-analysis.md
    │   ├── 04-market-positioning.md
    │   ├── 05-market-sizing.md
    │   └── 06-market-validation.md
    ├── strategy/
    │   ├── README.md
    │   ├── 01-strategic-narrative-and-alignment.md
    │   ├── 02-target-segments-and-prioritization.md
    │   ├── 03-value-proposition-system.md
    │   ├── 04-business-model-and-gtm.md
    │   └── 05-strategic-trade-offs-and-guardrails.md
    ├── goals-and-metrics/
    │   ├── README.md
    │   ├── 01-north-star-and-input-metrics.md
    │   ├── 02-okrs.md
    │   └── 03-kpi-scorecard-and-review-cadence.md
    ├── personas-and-journey/
    │   ├── README.md
    │   ├── 01-design-personas.md
    │   ├── 02-journey-persona-a.md
    │   ├── 03-journey-persona-b.md
    │   └── 04-cross-cutting-touchpoints-and-opportunities.md
    ├── product-roadmap/
    │   ├── README.md
    │   ├── 01-roadmap-principles-cadence-and-guardrails.md
    │   ├── 02-strategic-themes-and-outcomes.md
    │   ├── 03-horizon-plan-now-next-later.md
    │   └── 04-traceability-upstream-downstream.md
    ├── prd/
    │   ├── README.md
    │   ├── 01-prd-tema-1.md
    │   ├── 02-prd-tema-2.md
    │   └── 03-non-functional-requirements.md
    └── reference/
        └── product-development-unified-template.md
```

---

## 3) Processo por etapa

> Esta tabela e o contrato de entrega entre produto, design e engenharia.


| #   | Etapa                                       | Objetivo da etapa                                                    | Entrada principal                                                 | Entregavel principal                                                  | Responsavel primario | Criterio de conclusao (gate)                               | Status              |
| --- | ------------------------------------------- | -------------------------------------------------------------------- | ----------------------------------------------------------------- | --------------------------------------------------------------------- | -------------------- | ---------------------------------------------------------- | ------------------- |
| 1   | Product Vision                              | Definir direcao de longo prazo e tese de valor                       | Hipoteses iniciais de problema, oportunidade e publico            | Statement de visao e principios de produto                            | `<OWNER_ETAPA_01>`   | Visao aprovada pelos stakeholders-chave                    | `<STATUS_ETAPA_01>` |
| 2   | Pesquisa de Mercado & Definicao do Problema | Validar se o problema e real, relevante e diferenciado               | Visao inicial + hipoteses de mercado/problema                     | Sintese de mercado + problema definido com evidencias                 | `<OWNER_ETAPA_02>`   | Problema priorizado com evidencias suficientes             | `<STATUS_ETAPA_02>` |
| 3   | Product Strategy                            | Traduzir visao em escolhas estrategicas de posicionamento e execucao | Visao validada + achados de pesquisa                              | Estrategia de produto (segmentos, proposta de valor, GTM, trade-offs) | `<OWNER_ETAPA_03>`   | Alinhamento executivo e trade-offs explicitos              | `<STATUS_ETAPA_03>` |
| 4   | Product Goals & Metricas (OKRs/KPIs)        | Definir sucesso de forma mensuravel                                  | Estrategia aprovada + baseline de dados                           | North Star, metricas de input, OKRs e scorecard de KPIs               | `<OWNER_ETAPA_04>`   | Metas com owner, baseline e cadencia acordadas             | `<STATUS_ETAPA_04>` |
| 5   | User Personas & User Journey Maps           | Tornar alvo e experiencia do usuario explicitos                      | Pesquisa qualitativa/quantitativa + segmentacao                   | Personas de desenho + jornadas ponta a ponta                          | `<OWNER_ETAPA_05>`   | Personas/jornadas usadas para decidir roadmap e PRD        | `<STATUS_ETAPA_05>` |
| 6   | Product Roadmap                             | Sequenciar temas por impacto e incerteza                             | Estrategia + metas + personas/jornadas                            | Roadmap orientado a outcomes (Now/Next/Later)                         | `<OWNER_ETAPA_06>`   | Priorizacao, dependencias e alinhamento cross-funcional    | `<STATUS_ETAPA_06>` |
| 7   | PRD (Product Requirements Document)         | Converter temas em requisitos claros para entrega                    | Roadmap do horizonte Now + decisoes de produto/design/arquitetura | PRDs por tema com requisitos funcionais e nao-funcionais              | `<OWNER_ETAPA_07>`   | Escopo e criterios de aceite revisados por areas-chave     | `<STATUS_ETAPA_07>` |
| 8   | Epics & User Stories                        | Quebrar requisitos em incrementos planejaveis                        | PRD aprovado                                                      | Catalogo de epicos e historias com rastreabilidade                    | `<OWNER_ETAPA_08>`   | Historias estimaveis, testaveis e prontas para sprint      | `<STATUS_ETAPA_08>` |
| 9   | Prototipos & Wireframes                     | Validar fluxos e decisoes de UX antes do desenvolvimento             | Historias priorizadas + jornadas + diretrizes de design           | Wireframes/prototipos por fluxo critico com feedback                  | `<OWNER_ETAPA_09>`   | Fluxos criticos validados sem riscos graves de usabilidade | `<STATUS_ETAPA_09>` |
| 10  | Product Backlog                             | Consolidar e priorizar continuamente o trabalho                      | Epics/stories + prototipos + bugs + debitos tecnicos              | Backlog priorizado e refinado conectado aos objetivos                 | `<OWNER_ETAPA_10>`   | Proximo ciclo pronto com prioridades e dependencias claras | `<STATUS_ETAPA_10>` |


---

## 4) Detalhamento operacional por etapa

### 1. Product Vision

- **Pergunta-chave**: para onde estamos indo?
- **Atividades**: clarificar problema-alvo, oportunidade e proposta de valor macro.
- **Artefatos esperados**: statement de visao e principios.
- **Link da etapa**: `<LINK_ETAPA_01>`

### 2. Pesquisa de Mercado & Definicao do Problema

- **Pergunta-chave**: o problema e real e relevante?
- **Atividades**: pesquisa de concorrentes, entrevistas, analise de sinais de mercado.
- **Artefatos esperados**: definicao do problema + evidencias.
- **Link da etapa**: `<LINK_ETAPA_02>`

### 3. Product Strategy

- **Pergunta-chave**: por qual caminho vamos chegar la?
- **Atividades**: definir segmentos prioritarios, proposta de valor, GTM e trade-offs.
- **Artefatos esperados**: narrativa estrategica e escolhas explicitas.
- **Link da etapa**: `<LINK_ETAPA_03>`

### 4. Product Goals & Metricas (OKRs/KPIs)

- **Pergunta-chave**: como sabemos que estamos no caminho certo?
- **Atividades**: selecionar North Star, metricas de input, objetivos e revisoes.
- **Artefatos esperados**: OKRs, KPIs e cadencia de acompanhamento.
- **Link da etapa**: `<LINK_ETAPA_04>`

### 5. User Personas & User Journey Maps

- **Pergunta-chave**: quem sao os usuarios e como vivenciam o problema?
- **Atividades**: sintetizar personas de desenho e mapear jornadas ponta a ponta.
- **Artefatos esperados**: personas + jornadas com dores, momentos de valor e oportunidades.
- **Link da etapa**: `<LINK_ETAPA_05>`

### 6. Product Roadmap

- **Pergunta-chave**: o que vem primeiro, depois e mais adiante?
- **Atividades**: priorizar outcomes por impacto, esforco e risco (Now/Next/Later).
- **Artefatos esperados**: roadmap orientado a outcomes com rastreabilidade para metas.
- **Link da etapa**: `<LINK_ETAPA_06>`

### 7. PRD (Product Requirements Document)

- **Pergunta-chave**: o que o produto precisa fazer?
- **Atividades**: detalhar requisitos funcionais e nao-funcionais por tema.
- **Artefatos esperados**: PRDs com criterios de aceite claros.
- **Link da etapa**: `<LINK_ETAPA_07>`

### 8. Epics & User Stories

- **Pergunta-chave**: como transformar requisitos em trabalho executavel?
- **Atividades**: quebrar PRD em epicos e historias no formato "Como..., quero..., para...".
- **Artefatos esperados**: backlog de historias rastreavel ao PRD/roadmap.
- **Link da etapa**: `<LINK_ETAPA_08>`

### 9. Prototipos & Wireframes

- **Pergunta-chave**: como a experiencia deve parecer e funcionar?
- **Atividades**: esbocos, wireframes e prototipos com validacao.
- **Artefatos esperados**: fluxos criticos validados com usuarios/stakeholders.
- **Link da etapa**: `<LINK_ETAPA_09>`

### 10. Product Backlog

- **Pergunta-chave**: qual e a proxima coisa mais importante a construir?
- **Atividades**: consolidar historias, bugs e debitos tecnicos com priorizacao continua.
- **Artefatos esperados**: backlog refinado para o proximo ciclo.
- **Link da etapa**: `<LINK_ETAPA_10>`

---

## 5) Como usar em outro projeto

1. Copie este arquivo para `docs/product/reference/` do novo repositorio.
2. Preencha os placeholders (`<...>`) com contexto do novo produto.
3. Ajuste o mapa de pastas para refletir a realidade do time (sem remover as 10 etapas sem justificativa).
4. Crie/atualize `docs/product/index.md` para apontar para os artefatos reais.
5. Defina owners por etapa e cadencia de revisao de status (semanal ou quinzenal).
6. Trave os gates da tabela de processo como criterio para avancar etapas.

---

## 6) Checklist rapido de adaptacao

- Nome do produto, publico e resumo preenchidos
- Owners definidos para as 10 etapas
- Status inicial de todas as etapas definido
- Links dos artefatos principais atualizados
- Gates revisados e aceitos por stakeholders
- Cadencia de revisao combinada e documentada

