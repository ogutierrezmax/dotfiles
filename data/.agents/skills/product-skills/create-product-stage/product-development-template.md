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
| 2   | Pesquisa de Mercado & Definicao do Problema | Validar se o problema e real, relevante e diferenciado; profundidade proporcional ao risco (ver secao 4) | Visao inicial + hipoteses de mercado/problema                     | Sintese de mercado + problema definido com evidencias                 | `<OWNER_ETAPA_02>`   | Problema priorizado com evidencias adequadas ao contexto; registrar reducao de escopo se houver | `<STATUS_ETAPA_02>` |
| 3   | Product Strategy                            | Traduzir visao em escolhas estrategicas de posicionamento e execucao | Visao validada + achados de pesquisa                              | Estrategia de produto (segmentos, proposta de valor, GTM, trade-offs) | `<OWNER_ETAPA_03>`   | Alinhamento executivo e trade-offs explicitos              | `<STATUS_ETAPA_03>` |
| 4   | Product Goals & Metricas (OKRs/KPIs)        | Definir sucesso de forma mensuravel; intensidade minima ou provisoria em discovery (ver secao 4) | Estrategia aprovada + baseline de dados                           | North Star, metricas de input, OKRs e scorecard de KPIs               | `<OWNER_ETAPA_04>`   | Metas com owner e cadencia acordadas; baseline ou plano explicito se ainda inexistente | `<STATUS_ETAPA_04>` |
| 5   | User Personas & User Journey Maps           | Tornar alvo e experiencia explicitos (usuario final ou perfis tecnicos/operacionais — ver secao 4) | Pesquisa qualitativa/quantitativa + segmentacao                   | Personas de desenho + jornadas ponta a ponta                          | `<OWNER_ETAPA_05>`   | Alvo e jornada usados para roadmap e PRD (personas completas, proto-personas ou equivalente registrado) | `<STATUS_ETAPA_05>` |
| 6   | Product Roadmap                             | Sequenciar temas por impacto e incerteza                             | Estrategia + metas + personas/jornadas                            | Roadmap orientado a outcomes (Now/Next/Later)                         | `<OWNER_ETAPA_06>`   | Priorizacao, dependencias e alinhamento cross-funcional    | `<STATUS_ETAPA_06>` |
| 7   | PRD (Product Requirements Document)         | Converter temas em requisitos claros para entrega                    | Roadmap do horizonte Now + decisoes de produto/design/arquitetura | PRDs por tema com requisitos funcionais e nao-funcionais              | `<OWNER_ETAPA_07>`   | Escopo e criterios de aceite revisados por areas-chave     | `<STATUS_ETAPA_07>` |
| 8   | Epics & User Stories                        | Quebrar requisitos em incrementos planejaveis; formato user story ou equivalente acordado (ver secao 4) | PRD aprovado                                                      | Catalogo de epicos e historias com rastreabilidade                    | `<OWNER_ETAPA_08>`   | Incrementos rastreaveis ao PRD, estimaveis e testaveis (historias, RFC+tarefas ou mix registrado) | `<STATUS_ETAPA_08>` |
| 9   | Prototipos & Wireframes                     | Validar fluxos e decisoes de UX/UI antes do desenvolvimento (produtos com interface); **pular a etapa** se nao for necessaria — ver secao 4 | Historias priorizadas + jornadas + diretrizes de design           | Wireframes/prototipos por fluxo critico com feedback                  | `<OWNER_ETAPA_09>`   | Fluxos criticos validados sem riscos graves de usabilidade, ou etapa pulada com registro | `<STATUS_ETAPA_09>` |
| 10  | Product Backlog                             | Consolidar e priorizar continuamente o trabalho                      | Epics/stories + bugs + debitos; prototipos somente se etapa 9 executada; demais insumos do PRD/contratos quando aplicavel | Backlog priorizado e refinado conectado aos objetivos                 | `<OWNER_ETAPA_10>`   | Proximo ciclo pronto com prioridades e dependencias claras | `<STATUS_ETAPA_10>` |


---

## 4) Detalhamento operacional por etapa

### 1. Product Vision

- **Pergunta-chave**: para onde estamos indo?
- **Atividades**: clarificar problema-alvo, oportunidade e proposta de valor macro.
- **Artefatos esperados**: statement de visao e principios.
- **Link da etapa**: `<LINK_ETAPA_01>`

### 2. Pesquisa de Mercado & Definicao do Problema

- **Profundidade e contexto**: a **intensidade** da pesquisa deve ser **proporcional ao risco e a incerteza**. Produto **interno**, demanda ja conhecida ou problema validado em outro canal permitem **escopo reduzido** (ex.: stakeholders, dados internos, benchmark rapido em vez de estudo amplo). **Registre** a reducao, os limites do que foi validado e o que segue em aberto.
- **Evidencia minima**: leveza nao e ausencia de evidencia — mesmo enxuto, o entregavel precisa de **fundamento registrado** para o nivel de decisao em curso.
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

- **Discovery e baseline**: em **discovery** ou sem historico de dados, e aceitavel conjunto **minimo ou provisorio**: North Star **candidata**, metricas com **hipotese de medicao**, OKRs/KPIs **revisaveis** apos baseline. **Documente** o que e provisorio, o owner da evolucao para versao madura e prazo ou gatilho de revisao.
- **Pergunta-chave**: como sabemos que estamos no caminho certo?
- **Atividades**: selecionar North Star, metricas de input, objetivos e revisoes.
- **Artefatos esperados**: OKRs, KPIs e cadencia de acompanhamento.
- **Link da etapa**: `<LINK_ETAPA_04>`

### 5. User Personas & User Journey Maps

- **Escopo**: com **interface de usuario** classica, use personas de desenho e jornadas ponta a ponta. Para **API, plataforma, ferramenta interna ou publico tecnico**, o alvo costuma ser **papeis** (ex.: integrador, SRE, analista) e a jornada **operacional** (onboarding tecnico, integracao, incidente, rollout) — nao force jornada de consumidor onde nao couber.
- **Simplificacao**: com baixo risco de desalinhamento, **proto-personas**, sintese de **jobs-to-be-done** ou mapa de **atores e sistemas** podem substituir pacotes completos, desde que **rastreaveis** ao roadmap e ao PRD. **Registre** o nivel de fidelidade escolhido.
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

- **Formato**: o padrao e **historias de usuario** rastreaveis ao PRD. Em dominios **fortemente tecnicos ou de plataforma**, e aceitavel **equivalente acordado**: ex. **RFC** + epico tecnico + tarefas, ou requisitos por **contrato**, desde que mantenham **rastreabilidade ao PRD**, **criterios de aceite** e condicoes de **estimar e testar**.
- **Consistencia**: deixe explicito no time qual **nomenclatura e ferramenta** cumprem o mesmo papel das user stories (refinamento e prontidao para sprint).
- **Pergunta-chave**: como transformar requisitos em trabalho executavel?
- **Atividades**: quebrar PRD em epicos e historias no formato "Como..., quero..., para...".
- **Artefatos esperados**: backlog de historias rastreavel ao PRD/roadmap.
- **Link da etapa**: `<LINK_ETAPA_08>`

### 9. Prototipos & Wireframes

- **Escopo**: aplica-se a produtos com **interface de usuario** (web, mobile, desktop ou equivalente). O foco e a **experiencia e a interacao** validadas antes da implementacao na **camada de apresentacao** — em muitos times isso acompanha o trabalho de frontend, sem prescrever stack nem substituir especificacao de API/backend.
- **Quando nao for necessaria**: **pule esta etapa** (nao a adie com artefatos vazios nem a cumprir por formalismo). Avance no processo sem prototipos/wireframes quando PRD, historias ou outros artefatos ja forem suficientes, quando nao houver superficie de UI, ou quando o risco de UX ja estiver aceito de outra forma. **Registre sempre** a dispensa com motivo e responsavel no processo de governanca.
- **Produtos sem UI direta** (ex.: API pura, pipelines, bibliotecas internas): em regra, **pule**; se o time quiser algo equivalente, pode produzir fluxos de consumo, integracao ou documentacao de contrato — **opcional**, nao substituto obrigatorio ao ato de pular.
- **Pergunta-chave**: como a experiencia deve parecer e funcionar?
- **Atividades**: esbocos, wireframes e prototipos com validacao.
- **Artefatos esperados**: fluxos criticos validados com usuarios/stakeholders.
- **Link da etapa**: `<LINK_ETAPA_09>`

### 10. Product Backlog

- **Insumos**: consolida epics/historias (ou **equivalentes da etapa 8**), bugs e debito tecnico. **Prototipos/wireframes** entram como referencia **somente se a etapa 9 tiver sido executada**; se a etapa 9 foi **pulada**, apoie-se em **PRD, contratos, especificacoes ou diagramas** ja existentes — **sem** inventar prototipo por formalismo.
- **Priorizacao**: mantenha ligacao explicita aos **objetivos** (etapa 4) e ao **roadmap** quando o ciclo exigir.
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

