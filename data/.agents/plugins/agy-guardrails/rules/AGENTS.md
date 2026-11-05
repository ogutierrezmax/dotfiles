# Regras Globais de Governança e Execução (`agy-guardrails`)

## 1. Protocolo Estrito: Explore → Plan → Execute
- **Exploração Antes de Edição**: Nunca edite arquivos (`edit_file`, `write_file`) sem antes inspecionar os símbolos e referências afetados.
- **Gatilho de Planejamento**: Para tarefas que modifiquem **3 ou mais arquivos**, alterem contratos de API/schemas ou envolvam refatorações estruturais, apresente obrigatoriamente antes de editar:
  1. Lista exata de arquivos que serão criados, modificados ou removidos.
  2. Impactos colaterais e riscos identificados.
  3. Comandos de verificação que serão executados ao final.
  4. Aguarde confirmação do usuário (ou utilize o modo `/plan`).

## 2. Higiene da Janela de Contexto (`context-mode` — Derive, Don't Dump)
- **Proibição de Dumps Brutos**: Nunca despeje arquivos inteiros (>150 linhas), logs extensos, JSONs grandes ou HTML bruto na conversa via `run_command` (`cat`, `head`/`tail` longos, `curl` sem filtro).
- **Roteamento para Sandbox**:
  - Para analisar, contar, filtrar ou resumir o conteúdo de um arquivo: use `context-mode/ctx_execute_file` (variável `FILE_CONTENT` na sandbox) e imprima **apenas a resposta derivada**.
  - Para múltiplos comandos de reconhecimento do repositório: agrupe em uma única chamada `context-mode/ctx_batch_execute`.
  - Para preservar contexto entre compactações (`/compact`) ou consultar documentações longas: indexe com `context-mode/ctx_index` (SQLite FTS5 / BM25) e consulte via `context-mode/ctx_search`.

## 3. Loops de Verificação Obrigatórios e Proteção de Testes
- **Proibição de Adulteração de Testes**: É expressamente proibido remover, comentar ou afrouxar asserções em testes existentes (`*.test.*`, `*.spec.*`, `*_test.*`) apenas para forçar aprovação sem autorização explícita do usuário.
- **Verificação Antes de Concluir**: Nenhuma tarefa de código está concluída até que o verificador correspondente ao projeto passe sem erros:
  - **TypeScript / JavaScript**: `npx tsc --noEmit` e suíte de testes (`npm test` / `npx vitest run`).
  - **Rust**: `cargo check` e `cargo test`.
  - **Python**: `pyright` e `pytest`.
  - **Shell Scripts (`.sh`)**: `shellcheck <arquivo>`.

## 4. Diretriz "No Chatter" e Economia de Tokens (Estilo OpenCode)
- **Zero Preâmbulo e Postâmbulo**: Vá direto à resposta ou à execução de ferramentas. Nunca inicie com frases como *"Vou analisar..."*, *"Com base no código..."* ou *"Aqui está a resposta:"*, nem finalize repetindo o que acabou de fazer.
- **Proibição de Ecoar Diffs**: Após usar `edit_file` ou `write_file`, **nunca** reimprima o bloco de código editado no chat (o usuário já visualiza o diff na interface). Resuma a mudança em no máximo 1–3 bullets curtos com links para os símbolos/linhas alterados.
- **Brevidade Calibrada**: Para perguntas diretas ou comandos rápidos, responda em 1–4 linhas. Só elabore explicações detalhadas quando o usuário perguntar explicitamente *"como"* ou *"por quê"*.
- **Paralelismo de Ferramentas**: Agrupe chamadas independentes de leitura/busca (`read_file`, `ctx_batch_execute`) no mesmo turno para minimizar ciclos de *reasoning*.
