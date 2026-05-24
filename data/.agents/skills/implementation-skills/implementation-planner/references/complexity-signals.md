# Sinais de Complexidade

Use este arquivo para decidir se uma tarefa deve ser upclassificada para COMPLEXA mesmo que pareça simples à primeira vista.

## Sinais de alerta imediato (→ COMPLEXA)

- Mudança de schema de banco de dados (migration)
- Alteração de contrato de API pública ou interna
- Introdução de novo serviço externo (pagamento, autenticação, storage)
- Refatoração que afeta mais de 5 arquivos
- Feature que envolve estado assíncrono (queue, jobs, websockets)
- Qualquer coisa que envolva autenticação ou autorização
- Mudança em lógica de negócio crítica (precificação, cálculo financeiro, permissões)
- Introdução de cache com invalidação complexa

## Sinais de alerta moderado (→ MÉDIA no mínimo)

- Adicionar novo endpoint REST/GraphQL com validação
- Criar novo componente de UI que se comunica com API
- Implementar nova regra de negócio com edge cases
- Qualquer feature que precise de testes de integração
- Alterar comportamento de feature existente (risco de regressão)

## Perguntas de diagnóstico rápido

1. "Se isso quebrar em produção, qual o impacto?" → Se alto: COMPLEXA
2. "Quantos arquivos vou abrir para implementar?" → Se > 3: MÉDIA ou COMPLEXA
3. "Existe algum estado compartilhado envolvido?" → Se sim: MÉDIA ou COMPLEXA
4. "Outro desenvolvedor vai precisar saber desta mudança?" → Se sim: documente na spec

## Heurística de granularidade de passo

Um passo está bem dimensionado quando:
- Pode ser descrito em 1 frase de ação ("Crie o model User com campos X, Y, Z")
- Gera entre 20–150 linhas de código novo
- Pode ser testado isoladamente com no máximo 1–2 chamadas de função/endpoint
- Não depende de nada que ainda não existe no codebase

Um passo está grande demais quando:
- Você usa "e" para descrevê-lo ("Crie o model **e** implemente o service **e** adicione o endpoint")
- Vai gerar mais de 200 linhas
- Mexe em mais de 3 arquivos
