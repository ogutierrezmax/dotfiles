#!/usr/bin/env bash
set -euo pipefail

# Fail-open seguro: qualquer erro devolve JSON vazio para nunca travar o agente
trap 'printf "{}\n"; exit 0' ERR

payload=$(cat)
model_name=$(printf '%s' "$payload" | jq -r '.modelName // empty' 2>/dev/null || true)

if [ -z "$model_name" ] || [ "$model_name" = "auto" ]; then
  settings_file="${HOME}/.gemini/antigravity-cli/settings.json"
  if [ -f "$settings_file" ]; then
    model_name=$(jq -r '.model // empty' "$settings_file" 2>/dev/null || true)
  fi
fi

model_lc=$(printf '%s' "$model_name" | tr '[:upper:]' '[:lower:]')

case "$model_lc" in
  *claude*|*anthropic*|*sonnet*|*opus*|*haiku*)
    msg="[Harness/Anthropic]: Suprima preâmbulos ('Certo, vou...', 'Entendi') e resumos pós-ação. Não reimprima código aplicado via edit_file/write_file. Seja cirúrgico e responda em <= 4 linhas fora blocos de código essenciais."
    ;;
  *gemini*|*argon*|*flash*)
    msg="[Harness/Gemini]: Evite explicações teóricas/didáticas não solicitadas e listas longas. Paralelize tool calls independentes no mesmo turno. Vá direto ao ponto técnico com densidade máxima e zero rodeios."
    ;;
  *gpt*|*openai*|*o1*|*o3*|*o4*|*codex*)
    msg="[Harness/OpenAI]: Priorize tools dedicadas (read_file, edit_file, context-mode) em vez de shell (run_command). Faça edições mínimas ancoradas sem reescrever código adjacente. Resposta direta, sem introduções ou conclusões."
    ;;
  *)
    msg="[Harness]: Maximize eficiência de tokens: zero conversa fiada (no chatter), sem preâmbulos, sem repetir diffs no chat."
    ;;
esac

jq -cn --arg m "$msg" '{injectSteps: [{ephemeralMessage: $m}]}'
