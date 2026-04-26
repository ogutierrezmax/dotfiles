---
name: bug-investigation-report
description: Investiga a causa raiz de bugs com base em evidências e propõe múltiplas soluções avaliadas.
---

# Skill: bug-investigation-report

## Propósito
Investigar a causa provável de um bug/falha a partir de uma descrição e evidências (logs/stack traces), e devolver um relatório prático com:
- `## Motivos` (causa(s) raiz ou mais provável(is))
- `## Possíveis soluções` (várias opções) e, para cada opção, as notas: `Adequacao ao projeto (0-10)`, `Nível profissional (0-10)` e `Simplicidade (0-10)`.

## Quando usar
Use quando o usuário fornecer (mesmo que parcialmente):
- Descrição do bug (sintoma + comportamento esperado)
- Mensagem de erro/stack trace (se houver)
- Passos para reproduzir (se houver)
- Contexto (ambiente, versão, banco/serviço, commit/PR recente, etc.)

## Como aplicar
1. **Resumir o bug**: defina o que está falhando (onde/sintoma), o que deveria acontecer e quais sinais aparecem no erro.
2. **Coletar evidências**: extraia da entrada tudo que ajude a localizar (strings do erro, endpoint/ação afetada, IDs, timestamps, arquivos citados).
3. **Localizar no código**:
   - Use `rg` para encontrar mensagens de erro, nomes de funções/componentes e rotas/handlers citados.
   - Mapear o fluxo: entrada -> validação -> lógica -> persistência -> resposta.
4. **Validar hipótese**:
   - Se houver testes, rode os testes relacionados (ou o comando de verificação mais próximo: lint/typecheck/build).
   - Se não for possível reproduzir, explique claramente a diferença entre “provável” e “confirmado”.
5. **Construir o relatório**:
   - Liste `## Motivos` em ordem de probabilidade (1º = mais provável).
   - Liste `## Possíveis soluções` em ordem de “equilíbrio” (mais segura e aderente ao projeto primeiro), mantendo cada solução independente.
6. **Fechar com qualidade**: indique o nível de confiança e o que faltaria para confirmar (ex.: “precisa do log X / executar cenário Y”).

## Formato (saída obrigatória)
Devolva exatamente este formato:

```markdown
## Entendimento do bug
Esperado (comportamento correto): <uma frase clara sobre o que deveria acontecer>.
Obtido (bug): <uma frase clara sobre o que está acontecendo na prática>.

## Motivos
1. [Motivo mais provável] — [1-2 frases: qual falha, onde aparece no fluxo e por quê].
2. [Motivo secundário] — [1-2 frases].

## Possíveis soluções
### Opção 1
Adequacao ao projeto (0-10): <n>
Nível profissional (0-10): <n>
Simplicidade (0-10): <n>

- Descrição: <o que mudar> — <por que tende a resolver>.
- Impacto/Riscos: <o que pode quebrar ou exigir cuidado>.
- Como validar: <como confirmar via teste/log/feature flag>.

### Opção 2
Adequacao ao projeto (0-10): <n>
Nível profissional (0-10): <n>
Simplicidade (0-10): <n>

- Descrição: <...>.
- Impacto/Riscos: <...>.
- Como validar: <...>.
```

## Checklist de qualidade (antes de retornar)
- Os `## Motivos` explicam a causa com base em sinais/evidências da entrada (ou deixam claro o que é inferência).
- As `## Possíveis soluções` são diferentes entre si (não variações do mesmo ajuste pequeno).
- Cada solução inclui validação objetiva (teste, log, passo de reprodução).
- As notas respeitam o sentido pedido:
  - `Adequacao ao projeto`: 0 = gambiarra fora do estilo; 10 = altamente alinhado ao padrão do repo/stack.
  - `Nível profissional`: 0 = gambiarra máxima; 10 = solução robusta e bem integrada.
  - `Simplicidade`: 0 = muito difícil; 10 = simples máxima.

## Nunca invoque quando
- Não houver descrição de bug nem qualquer evidência/sintoma para orientar a investigação.
- O pedido for apenas “corrigir rapidamente” sem contexto mínimo (nesse caso, primeiro peça passos para reproduzir e a mensagem de erro).
