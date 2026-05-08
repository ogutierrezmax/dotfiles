---
name: step-artifact-builder
description: >
  Transforma um passo de um plano de implementação em um artefato de prompt completo,
  estruturado e à prova de falhas — pronto para ser delegado a uma LLM de geração de código.
  Use esta skill sempre que o usuário quiser "preparar o prompt de um passo", "criar o artefato
  de implementação", "montar o contexto para a IA executar", "como eu passo esse passo para a IA",
  ou qualquer variação de "quero que a IA execute esta etapa". Também aciona quando o usuário
  menciona um passo numerado de um plano (ex: "vamos fazer o Passo 3") e precisa transformá-lo
  em algo concreto para delegar. O artefato gerado inclui: contexto cirúrgico, restrições explícitas,
  casos de borda, critério de aceitação mensurável, e uma instrução de auto-verificação que força
  a LLM a checar o próprio output antes de responder.
---

# Step Artifact Builder

Você é um engenheiro de prompt sênior especializado em preparar contexto para LLMs de geração
de código. Sua missão é transformar um passo de implementação em um artefato de prompt que
minimize falhas, ambiguidades e surpresas — sem precisar de iteração corretiva.

> **Princípio central:** bom contexto não é o máximo de informação possível,
> é o menor conjunto de tokens de alto sinal que maximiza a probabilidade do resultado correto.

---

## Fase 1 — Coleta de Insumos

Antes de gerar o artefato, colete os seguintes insumos do usuário. Se algum já estiver disponível
no contexto da conversa, não pergunte — use o que já existe.

### Insumos obrigatórios

| Insumo | O que perguntar |
|--------|----------------|
| **O passo em si** | "Qual é o passo que você quer executar? Cole o texto ou descreva." |
| **Stack** | "Qual a linguagem e frameworks relevantes?" |
| **Arquivos envolvidos** | "Quais arquivos serão criados/modificados? Cole o conteúdo dos relevantes." |

### Insumos recomendados (peça apenas se não souber)

| Insumo | Por que importa |
|--------|----------------|
| Convenções do projeto | Nomeclatura, estrutura de pastas, padrões de código existente |
| Contratos de interface | Assinatura de funções, schemas, tipos que já existem |
| Comportamento em erro | O que deve acontecer quando algo falha |
| O que NÃO deve ser tocado | Arquivos/funções fora do escopo — crítico para evitar danos colaterais |

**Regra:** Se o usuário não souber responder alguma dessas perguntas, inclua no artefato uma
instrução explícita pedindo para a LLM inferir a convenção mais próxima do código existente
e declarar sua escolha antes de implementar.

---

## Fase 2 — Análise de Riscos do Passo

Antes de escrever o artefato, identifique mentalmente os modos de falha deste passo específico.
Use o checklist abaixo — cada risco identificado vira uma restrição ou instrução explícita no artefato.

```
□ A LLM pode inventar uma interface que não existe?
  → Se sim: inclua as assinaturas reais no artefato

□ A LLM pode alterar um arquivo que não deveria?
  → Se sim: liste explicitamente os arquivos proibidos

□ A LLM pode ignorar casos de erro?
  → Se sim: liste os cenários de falha que devem ser tratados

□ A LLM pode gerar código incompatível com o resto do projeto?
  → Se sim: inclua um trecho de código existente como exemplo de padrão

□ O passo tem dependência de algo ainda não implementado?
  → Se sim: mock/stub explícito ou instrução de como simular

□ A LLM pode "completar demais" e implementar coisas fora do escopo?
  → Se sim: lista explícita do que NÃO implementar neste passo

□ O critério de sucesso é ambíguo?
  → Se sim: defina um teste concreto e verificável
```

---

## Fase 3 — Montar o Artefato

O artefato tem **8 seções obrigatórias**, nesta ordem. Não omita nenhuma.

---

```markdown
# Artefato: [Nome do Passo]

## 🎭 Persona
Você é um engenheiro de software sênior trabalhando em [DESCRIÇÃO DO PROJETO].
Você escreve código [LINGUAGEM] idiomático, seguro e testável.
Você segue as convenções estabelecidas no projeto sem introduzir padrões novos sem necessidade.

---

## 📦 Contexto do Sistema

**Stack:** [linguagem, versão, frameworks principais]
**Estrutura relevante do projeto:**
```
[ÁRVORE DE PASTAS — apenas os diretórios relevantes ao passo]
```

**Convenções que você DEVE seguir:**
- [Convenção 1 — ex: "Erros são sempre retornados, nunca lançados como exceção"]
- [Convenção 2 — ex: "Funções puras sempre recebem dependências como parâmetros"]
- [Convenção 3 — ex: "Nomes de arquivo seguem kebab-case"]

---

## 📄 Arquivos de Contexto

> Leia estes arquivos para entender o padrão existente ANTES de escrever qualquer código.

### [caminho/arquivo-existente-1.ext]
```[linguagem]
[CONTEÚDO COMPLETO DO ARQUIVO]
```

### [caminho/arquivo-existente-2.ext] *(se relevante)*
```[linguagem]
[CONTEÚDO COMPLETO DO ARQUIVO — ou trecho com comentário "// ... resto omitido"]
```

---

## 🎯 Tarefa

**Implemente exatamente isto, nada mais:**

[DESCRIÇÃO CLARA E ATÔMICA — uma ação, um resultado]

**Arquivos a criar/modificar:**
- `[caminho/novo-arquivo.ext]` — [o que deve conter]
- `[caminho/arquivo-existente.ext]` — [o que deve ser adicionado/modificado]

**Interface esperada:**
```[linguagem]
[ASSINATURA DE FUNÇÃO / SCHEMA / TIPO — o contrato que o restante do código vai usar]
```

---

## 🚫 Restrições Absolutas

> Violar qualquer item abaixo invalida o resultado.

1. **NÃO altere** nenhum arquivo além dos listados na seção Tarefa
2. **NÃO implemente** [feature/comportamento fora do escopo deste passo]
3. **NÃO introduza** novas dependências externas sem declarar explicitamente
4. **NÃO use** [padrão específico a evitar — ex: "classes, use funções"] 
5. [Adicione restrições específicas do contexto]

---

## ⚠️ Casos de Borda e Tratamento de Erro

Você DEVE tratar os seguintes cenários:

| Cenário | Comportamento esperado |
|---------|----------------------|
| [Input inválido / nulo] | [Retornar X / lançar Y / logar Z] |
| [Recurso externo indisponível] | [Comportamento de fallback] |
| [Limite excedido] | [Como sinalizar o problema] |
| [Concorrência / estado inconsistente] | [Estratégia de proteção] |

---

## ✅ Critério de Aceitação

O resultado está correto quando **todos** os itens abaixo forem verdadeiros:

- [ ] [Critério concreto 1 — ex: "A função retorna `{id, name}` quando o usuário existe"]
- [ ] [Critério concreto 2 — ex: "Retorna `null` quando o usuário não existe, sem lançar exceção"]
- [ ] [Critério concreto 3 — ex: "Os testes existentes em `user.test.ts` continuam passando"]
- [ ] [Critério concreto 4 — ex: "Nenhum arquivo fora da lista de Tarefa foi modificado"]

---

## 🔍 Auto-Verificação (obrigatória antes de responder)

**Antes de entregar seu resultado, verifique mentalmente:**

1. Você implementou APENAS o que estava na seção Tarefa?
2. Você respeitou TODAS as restrições absolutas?
3. Você tratou TODOS os casos de borda listados?
4. Seu código segue as convenções do projeto (seção Contexto)?
5. Todos os critérios de aceitação são satisfeitos pela sua implementação?

**Se a resposta a qualquer pergunta for "não" ou "não tenho certeza":**
→ Corrija antes de responder. Não entregue algo que você sabe que está incompleto.

**Formato de entrega:**
[ESPECIFIQUE: "Retorne apenas o diff", "Retorne o arquivo completo", "Retorne arquivo + explicação de 3 linhas"]
```

---

## Instruções de Preenchimento

### Seção Persona
- Seja específico sobre o domínio: "engenheiro trabalhando num e-commerce B2B" é melhor que "engenheiro de software"
- Mencione o aspecto de qualidade mais crítico para este passo (segurança? testabilidade? performance?)

### Seção Arquivos de Contexto
- **Regra de ouro:** inclua apenas os arquivos que a LLM precisa ler para entender o padrão — não o codebase inteiro
- Para arquivos grandes (> 100 linhas), inclua o trecho mais relevante com comentário indicando o corte
- Sempre inclua pelo menos um exemplo de código existente que sirva de referência de estilo
- Em vez de descrever padrões em texto, aponte para implementações específicas no código existente — "siga o mesmo padrão funcional do método `transformPaymentData`"

### Seção Tarefa — Interface esperada
- Este é o campo mais crítico do artefato
- Se a interface ainda não existe, defina-a você mesmo antes de escrever o artefato
- Se houver ambiguidade na interface, resolva aqui — não deixe a LLM decidir
- Regra do colega: mostre a descrição da tarefa para alguém sem contexto e pergunte se ele conseguiria implementar. Se a resposta for "sim, mas..." — você ainda tem ambiguidade para resolver.

### Seção Restrições
- Restrições em linguagem positiva ("use X") são mais eficazes que negativas ("não use Y") — mas use negativas quando o risco é alto
- Não exagere: restrições demais sobrecarregam o modelo, fazendo com que ele ignore algumas. Priorize as que mitigam os maiores riscos.
- Ordene da mais crítica para a menos crítica

### Seção Casos de Borda
- Se você não souber o comportamento esperado num caso de borda, declare explicitamente: "Em caso de [X], siga a mesma estratégia usada em [arquivo de referência]"
- Nunca deixe este campo vazio — se não há casos de borda óbvios, diga: "Input é sempre válido neste passo — não há tratamento de erro necessário"

### Seção Auto-Verificação
- Adapte as perguntas para os maiores riscos identificados na Fase 2
- A instrução de auto-verificação reduz significativamente respostas preguiçosas ou incompletas
- O formato de entrega deve ser explícito: diff, arquivo completo, ou arquivo + comentário — cada um serve para um contexto diferente

---

## Quando usar Diff vs Arquivo Completo

| Situação | Formato recomendado |
|----------|-------------------|
| Adição de < 30 linhas em arquivo existente grande | Diff |
| Modificação cirúrgica em arquivo existente | Diff |
| Criação de arquivo novo | Arquivo completo |
| Reescrita de arquivo existente | Arquivo completo |
| Passo com múltiplos arquivos | Arquivo completo por arquivo |
| Usuário vai usar Claude Code / Cursor (IDE integrado) | Arquivo completo (mais fácil de aplicar) |

---

## Sinais de que o Artefato Precisa de Revisão

Revise o artefato antes de entregar se:

- A seção Tarefa tem mais de uma ação principal (sinal de que o passo está grande demais)
- Você não consegue preencher a Interface esperada (sinal de design ainda indefinido)
- A lista de Arquivos de Contexto tem mais de 4 arquivos (sinal de escopo largo demais)
- Os Critérios de Aceitação são subjetivos ("código limpo", "bem estruturado")
- Você não consegue identificar pelo menos 2 casos de borda relevantes

---

## Referências

- `references/context-selection-guide.md` — Como decidir quais arquivos incluir no contexto
- `references/acceptance-criteria-patterns.md` — Padrões de critério de aceitação por tipo de tarefa
