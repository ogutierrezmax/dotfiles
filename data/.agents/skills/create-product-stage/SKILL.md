---
name: create-product-stage
description: >-
  Cria uma nova etapa de artefatos de produto (ex.: estratégia, discovery) com
  estrutura, pesquisa de mercado e conteúdo denso. Use quando o usuário pedir
  nova etapa de produto, documentação de fase PM, ou artefatos em
  /docs/product/ desde o zero.
---

# Workflow: Criar Nova Etapa de Produto

Este workflow define o processo estrutural para criar ecossistemas de artefatos de produto **desde o início**, eliminando a necessidade de refinamentos posteriores. O processo foi formalizado a partir de experiências reais de criação de artefatos de produto e consiste em **8 etapas sequenciais**: bootstrap do [índice](docs/product/index.md) → entender → pesquisar → organizar → criar → normalizar → mapear dependências → validar.

> **Princípio Central:** Pesquisar e estruturar ANTES de criar elimina a necessidade de refinar depois. Artefatos devem nascer densos e maduros — nunca como meros "templates vazios".

---

## Etapas do Processo

### 0. 🚀 Bootstrap obrigatório do índice (`docs/product/index.md`)

- **Execução obrigatória:** rodar o script `bash /home/alfo/_Dev/.agents/skills/create-product-stage/bootstrap-product-index.sh` que garante a existência do `docs/product/index.md`
- Leia o arquivo `docs/product/index.md` completamente para que possamos saber onde estão todos os arquivos que impactão a etapa atual

### 1. 🎯 Elicitação de Contexto

- **Nunca gerar artefatos sem antes entender o contexto.** Isso evita retrabalho por desalinhamento.
- Antes de sugerir formatos ou estruturas para essa etapa de produto, compreenda ativamente o domínio:
  - Qual o objetivo final e o problema núcleo que esta etapa visa resolver?
  - Qual o escopo, ecossistema e o momento atual do projeto?

- **OBRIGATÓRIO** Não inicie a geração de arquivos ainda. Primeiro faça perguntas exploratórias para estabelecer a base mental.
- **Protocolo obrigatório para perguntas:** antes de elaborar qualquer pergunta da Etapa 1, carregar e aplicar o protocolo em `auto-share/AI-tools/protocols/ProCAD - Protocol for Contextualized Assisted Decisions.md`.
- **Falha de resolução do protocolo (bloqueante):**
  - Se o arquivo do ProCAD não existir ou não puder ser lido, solicitar ao usuário o caminho correto do arquivo ProCAD e esperar sua resposta.
  - Após solicitar o caminho, **interromper o fluxo** e **aguardar a resposta do usuário** antes de continuar qualquer etapa (incluindo pesquisa, estruturação ou geração de arquivos).
  - Só retomar quando o arquivo ProCAD for localizado e lido com sucesso.
- Use as seções informativas contidas no formato da pergunta (prós, contras, etc.) para prover o conhecimento necessário para entender a pergunta e fazer uma boa escolha.
- As perguntas devem seguir o ProCAD como padrão principal de decisão contextualizada; em caso de conflito de formato, o ProCAD prevalece para a forma de perguntar.
- **Saída:** Entendimento compartilhado do que será criado — alinhamento estratégico e compreensão clara da profundidade exigida.
- Após as respostas **registrar** na pasta da etapa um arquivo chamado `decisões.md` todas as perguntas com suas opções e marcar o que foi escolhido para consulta futura.

### 2. 🔍 Pesquisa de Padrões de Mercado

- **A pesquisa não é opcional.** Sem ela, os artefatos nascem com nomenclatura errada, em quantidade excessiva ou com lacunas estruturais.
- **Antes de pesquisar na web, sempre verifique cache local de pesquisa** em `/home/alfo/_Dev/.agents/skills/create-product-stage/.cache`.
- Regras de cache (obrigatórias):
  - Se existir resultado de pesquisa com data de atualização nos **últimos 30 dias**, **não** executar pesquisa web; reutilize os dados locais como fonte primária.
  - Se não existir resultado recente (pasta vazia, inexistente ou arquivos com mais de 30 dias), aí sim execute pesquisa web.
  - Se a pasta `.cache` não existir, crie a pasta antes de persistir os resultados.
  - Após pesquisar na web, **salve/atualize** os resultados na pasta `.cache` para reutilização futura.
  - Mantenha ao menos: resumo da pesquisa, fontes consultadas (URLs), data/hora da coleta e tema pesquisado.
- Estrutura obrigatória de cache:
  - `.cache/index.json` (índice consolidado do cache).
  - `.cache/<tema-slug>.md` (um arquivo por tema de pesquisa).
- Contrato mínimo de `index.json`:
  - `version` (versão do formato).
  - `last_updated_at` (ISO-8601 UTC).
  - `entries[]` com: `id`, `file`, `updated_at`, `expires_at`, `source_count`.
- Cabeçalho obrigatório em cada `<tema-slug>.md`:
  ```yaml
  ---
  id: "<tema-slug>"
  tema: "<tema-pesquisado>"
  updated_at: "YYYY-MM-DDTHH:mm:ssZ"
  expires_at: "YYYY-MM-DDTHH:mm:ssZ"
  sources:
    - "https://..."
  ---
  ```
- Regra de consistência entre subagente e agente principal:
  - O conteúdo salvo em `.cache/<tema-slug>.md` deve ser **o mesmo conteúdo** retornado pelo subagente de pesquisa para o agente orquestrador (principal), sem reinterpretação semântica.
  - Ajustes permitidos apenas de serialização/empacotamento (ex.: inclusão do cabeçalho YAML e atualização do `index.json`), preservando integralmente o corpo textual retornado.
- Utilize `search_web` para mapear os padrões da indústria (Product Management Society, metodologias ágeis, Continuous Discovery, etc.).
- Identifique os artefatos vitais, filtrando o que faz sentido para a complexidade levantada na Etapa 1:
  - **Quais e quantos** artefatos o mercado recomenda (focando na quantidade adequada para evitar fadiga de documentação).
  - **Qual a anatomia esperada** de cada artefato (quais tópicos essenciais ele *deve* ter para não ser superficial).
  - **Qual a nomenclatura universal** (evite jargões isolados).
- Apresente ao usuário a lista de artefatos recomendados e peça aprovação.
- A topologia de diretórios e nomes de arquivos físicos ficam **apenas** na Etapa 3; nesta etapa fica o blueprint lógico (artefatos e propósitos).
- **Saída:** Blueprint aprovado de artefatos com nomes e propósitos padronizados.

### 3. 🏗️ Definição Estrutural

- **Definir a estrutura antes de criar os arquivos.** Isso evita o problema de "tudo solto" que gera refatoração posterior. A estrutura deve ser decidida *uma vez* e reutilizada.
- **ANTES de redigir qualquer texto**, isole os contêineres em **dois níveis** (não confundir):
  - **Raiz da documentação de produto:** diretório onde concentra *toda* a documentação de produto no repositório (padrão `/docs/product/`).
  - **Guarda-chuva da etapa:** pasta *filha* da raiz, com o *nome da etapa*, contendo *apenas* os artefatos dessa etapa (ex: `/docs/product/[nome-da-etapa]/`).
  - Estabeleça ordenação lógica *dentro* do guarda-chuva da etapa (ex: `01-contexto.md`, `02-pesquisa.md`).
- Construa a árvore de diretórios e avalie o impacto nos índices (como `index.md`).
- Apresente ao usuário rigorosamente a estrutura esperada.
- **Saída:** Árvore de diretórios aprovada pelo usuário.

> [!IMPORTANT]
> Gerar artefatos antes de definir a estrutura de pastas causa retrabalho para mover/reorganizar arquivos depois. Defina o contêiner e a ordem lógica antes de criar conteúdo.

### 4. 📝 Geração de Conteúdo

- **Um artefato por arquivo. Cada arquivo já nasce no local certo com o nome certo** (definido nas etapas 2 e 3).
- Com a estrutura chancelada, crie os artefatos fisicamente:
  - **Um arquivo por artefato** na localização acordada.
  - **Profundidade Imediata:** NUNCA crie arquivos que funcionem apenas como templates (com "a preencher", "lorem ipsum"). Utilize o contexto adquirido na Etapa 1 para preencher as seções de forma realista e argumentativa.
  - **Caso sinta falta de contexto:** Interrompa momentaneamente a geração (usando `notify_user`) fazendo perguntas focadas ao usuário para que o artefato seja instanciado com dados reais e contextuais.
  - **Gate por artefato:** Após cada arquivo (ou lote mínimo acordado), apresente ao usuário e obtenha OK **antes** de avançar para o próximo — salvo se o usuário pedir explicitamente rascunho em lote sem pausas.
- **Saída:** Arquivos Markdown criados na estrutura correta, com conteúdo denso, coerente e longevo.

### 5. 🏷️ Normalização Terminológica

- **Termos mudam ao longo do tempo. Documentar as variações evita confusão futura e facilita pesquisa.**
- Pesquise e documente sinônimos e variações de nomes utilizados no mercado para os conceitos abordados.
- Se aplicável, instancie de forma isolada ao longo dos arquivos:
  ```markdown
  > **Nota sobre Nomenclatura:** Este artefato/conceito também é referenciado no mercado como [variação 1], [variação 2]...
  ```
- **Saída:** Artefatos blindados contra confusões terminológicas futuras.

### 6. 🔗 Mapeamento de Dependências e Derivações

- **Nenhum artefato existe isolado.** Tornar as dependências explícitas permite navegação, auditoria de impacto e evita artefatos órfãos.
- Para cada artefato criado, adicione uma seção padronizada `## Dependências e Derivações` contendo:
  - **Depende de (upstream):** artefatos que foram insumo ou pré-requisito para a criação deste.
  - **Deriva para (downstream):** artefatos que utilizam este como insumo ou referência.
- Formato de cada sub-seção:
  ```markdown
  ### Depende de (upstream)
  | Etapa          | Artefato          | Nomes Alternativos                 |
  | -------------- | ----------------- | ---------------------------------- |
  | Product Vision | product-vision.md | Visão do Produto, Vision Statement |

  ### Deriva para (downstream)
  | Etapa            | Artefato   | Nomes Alternativos            |
  | ---------------- | ---------- | ----------------------------- |
  | Product Strategy | roadmap.md | Product Roadmap, Release Plan |
  ```
- A coluna **Nomes Alternativos** reaproveita o trabalho da Etapa 5 (Normalização Terminológica), facilitando pesquisa cruzada.
- **Saída:** Artefatos com grafo de dependências explícito e navegável.

### 7. ✅ Verificação Final

- **Cada artefato deve ser apresentado ao usuário para validação antes de prosseguir.**
- **Confirmação dos gates:** Garanta que cada artefato passou pelo gate da Etapa 4 (ou que o usuário dispensou pausas por escrito).
- **Aprovação qualitativa consolidada:** Revise com o usuário a completude e o alinhamento do *conteúdo gerado* ao blueprint e às expectativas.
- Execute as amarrações arquiteturais finais:
  - Atualize os índices consolidadores obrigatoriamente (como `index.md` ou `product-development-process.md`), adicionando links orgânicos para os novos arquivos da etapa.
  - Revise o `product-development-process.md` refletindo eventuais novos status ou etapas da jornada.
- Apresente ao usuário o mapa do ecossistema finalizado (arquivos e atualizações em cascata) para a anuência final chancelando que tudo está estruturado e navegável.
- **Saída:** Aprovação ou lista de ajustes pontuais — ecossistema de produto perfeitamente integrado, conteúdo gerado aprovado (gate de qualidade validado), e relatório operacional chancelado.