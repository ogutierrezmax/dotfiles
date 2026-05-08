# Templates de Prompt por Tipo de Tarefa

Use estes templates como base para os "prompts sugeridos" dentro dos planos.
Adapte substituindo os placeholders em MAIÚSCULAS.

---

## Criar novo módulo/serviço

```
Você está trabalhando em [STACK/FRAMEWORK].

Contexto: [O QUE EXISTE HOJE RELACIONADO].

Tarefa: Crie o arquivo `CAMINHO/ARQUIVO` implementando [DESCRIÇÃO FUNCIONAL].

Interface esperada:
[ASSINATURA DE FUNÇÃO / SCHEMA / ENDPOINT]

Restrições:
- Não altere nenhum arquivo existente
- Use [PADRÃO/CONVENÇÃO] consistente com o restante do projeto
- Trate os seguintes erros: [LISTA DE CASOS DE ERRO]

Critério de aceitação: [COMO TESTAR QUE FUNCIONOU]
```

---

## Adicionar feature em código existente

```
Arquivo atual: `CAMINHO/ARQUIVO` (conteúdo abaixo)

[CONTEÚDO RELEVANTE DO ARQUIVO]

Tarefa: Adicione [DESCRIÇÃO DA FEATURE] a este arquivo.

Regras:
- Não remova nenhuma função existente
- Mantenha a mesma estrutura de [MÓDULO/CLASSE/ESTILO]
- A nova função deve seguir o padrão: [EXEMPLO DE FUNÇÃO EXISTENTE]

Retorne apenas o diff ou o arquivo completo modificado.
```

---

## Refatorar sem mudar comportamento

```
O código abaixo implementa [DESCRIÇÃO]:

[CÓDIGO ATUAL]

Refatore para [OBJETIVO DA REFATORAÇÃO — ex: extrair para função pura, remover duplicação, etc.].

Regras absolutas:
- O comportamento externo NÃO deve mudar
- Os testes existentes devem continuar passando
- Não adicione funcionalidade nova
- [RESTRIÇÃO ESPECÍFICA]

Explique brevemente o que mudou e por quê.
```

---

## Corrigir bug

```
Contexto: [DESCRIÇÃO DO SISTEMA E O QUE DEVERIA ACONTECER]

Comportamento atual (bugado):
[DESCRIÇÃO DO BUG + STACK TRACE SE HOUVER]

Comportamento esperado:
[O QUE DEVERIA ACONTECER]

Arquivos relevantes:
[ARQUIVO 1 COM CONTEÚDO]
[ARQUIVO 2 SE NECESSÁRIO]

Encontre a causa raiz e proponha a correção mínima necessária.
Não altere nada além do necessário para corrigir o bug.
```

---

## Escrever testes

```
Implemente testes para a seguinte função/módulo:

[CÓDIGO A SER TESTADO]

Casos que devem ser cobertos:
1. Caminho feliz: [DESCRIÇÃO]
2. Edge case: [DESCRIÇÃO]
3. Erro esperado: [DESCRIÇÃO]
[ADICIONE MAIS SE NECESSÁRIO]

Use [FRAMEWORK DE TESTE].
Cada teste deve ser independente e não depender de estado externo (use mocks para [DEPENDÊNCIAS EXTERNAS]).
```

---

## Integrar com API externa

```
Contexto: Estou integrando com [NOME DA API]. Documentação relevante:

[TRECHO DA DOC OU ENDPOINT + SCHEMA DE RESPOSTA]

Tarefa: Implemente um serviço/módulo em [LINGUAGEM] que:
1. [AÇÃO 1 — ex: autentica com OAuth2]
2. [AÇÃO 2 — ex: faz request para GET /endpoint]
3. [AÇÃO 3 — ex: parseia a resposta e retorna no formato X]

Tratamento de erros:
- Rate limit (429): [ESTRATÉGIA — ex: retry com backoff]
- Timeout: [ESTRATÉGIA]
- Resposta inválida: [ESTRATÉGIA]

Não hardcode credenciais — use variáveis de ambiente: [LISTA DE ENV VARS].
```

---

## Criar migration de banco

```
ORM/banco: [EX: Prisma + PostgreSQL / Sequelize + MySQL]

Estado atual do schema (apenas tabelas relevantes):
[SCHEMA ATUAL]

Mudança necessária: [DESCRIÇÃO — ex: adicionar coluna X nullable à tabela Y]

Gere:
1. O arquivo de migration
2. O schema atualizado
3. [SE HOUVER DADOS EXISTENTES]: Script de backfill dos dados existentes

Atenção: A migration deve ser reversível (inclua o método down se o ORM suportar).
```
