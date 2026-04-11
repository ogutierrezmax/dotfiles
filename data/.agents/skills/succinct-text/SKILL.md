---
name: succinct-text
description: Reduz texto mantendo o conteúdo e a clareza. Use quando uma description de agente (.cursor/agents) ou de mcp_task ultrapassar o limite recomendado (~200 caracteres para agentes; 3–5 palavras para description do mcp_task), ou quando o usuário pedir texto mais sucinto/conciso.
---

# Texto sucinto (sem perder conteúdo)

Objetivo: encurtar o texto até o alvo de caracteres/palavras **sem remover informação essencial**. Priorize clareza e termos gatilho.

## Limites de referência

| Contexto | Limite recomendado |
|----------|--------------------|
| `description` de agente (`.cursor/agents/*.md`) | ~200 caracteres |
| `description` do mcp_task (resumo na UI) | 3–5 palavras |
| `prompt` do mcp_task | Autocontido; enxugar se estiver redundante ou prolixo |

## Técnicas (aplicar na ordem que fizer sentido)

1. **Pares redundantes** — Ficar com uma só palavra: "cada e todo" → "todo"; "completo e total" → "completo".
2. **Qualificadores desnecessários** — Remover: realmente, muito, basicamente, um pouco, extremamente, definitivamente, praticamente.
3. **Frases longas → uma palavra** — "devido ao fato de que" → "porque"; "com o propósito de" → "para"; "no caso de" → "se"; "é necessário que" → "deve".
4. **Voz passiva → ativa** — Sujeito no início + verbo direto: "foi escrito por X" → "X escreveu".
5. **Menos preposições** — Reduzir "de/para/em/em relação a" quando não forem essenciais; às vezes reescrever a frase resolve.
6. **Negativas → afirmativas** — "não deixe de" → "lembre-se de"; "se não tiver X, não faça Y" → "só faça Y se tiver X".
7. **Modificador já implícito** — Se o verbo/adjetivo já carrega o sentido, cortar o modificador: "antecipar de antemão" → "antecipar"; "revolucionar completamente" → "revolucionar".
8. **Verbos fortes** — Trocar "tem a capacidade de X" por "pode X" ou verbo único mais preciso.

## Checklist ao encurtar

- [ ] Todas as **ideias centrais** do texto original estão no resultado?
- [ ] **Termos gatilho** (para description de agente) foram mantidos?
- [ ] Frase ainda está **clara e inequívoca**?
- [ ] Tamanho final dentro do **limite** (ex.: ≤200 caracteres)?

## Exemplo (description de agente)

**Antes (longo):**  
"Este agente é um especialista de alto nível que ajuda na criação e também na otimização de subagentes do Cursor. Você deve usar quando estiver criando ou editando arquivos em .cursor/agents/, quando precisar decidir como delegar trabalho via subagentes, ou quando quiser otimizar subagentes que já existem. Use de forma proativa sempre que o usuário mencionar subagent, subagentes, delegar ou criar agente."

**Depois (~200 caracteres):**  
"Especialista de alto nível em criação e otimização de subagentes do Cursor. Use ao criar, editar ou revisar .cursor/agents/; ao delegar trabalho ou escolher subagent_type. Use de forma proativa para 'subagent', 'delegar' ou 'criar agente'."

## Uso pelo subagent-specialist

Ao produzir ou revisar um agente ou um payload de `mcp_task`:

- Se **description** do agente > ~200 caracteres → aplicar esta skill e reescrever até caber em ~200 caracteres, mantendo O QUÊ + QUANDO + gatilho proativo.
- Se **description** do mcp_task for mais que 3–5 palavras → resumir em 3–5 palavras; o detalhe fica no **prompt**.
- Se o **prompt** do mcp_task estiver repetitivo ou verboso → aplicar as técnicas acima ao prompt, sem cortar contexto necessário para o subagente executar.
