#!/usr/bin/env bash
set -euo pipefail

payload=$(cat)
target_path=$(printf '%s' "$payload" | jq -r '.toolCall.args.Path // .toolCall.args.TargetFile // empty' 2>/dev/null || true)

if [ -z "$target_path" ]; then
  printf '{"decision":"allow"}\n'
  exit 0
fi

case "$target_path" in
  *.test.*|*.spec.*|*_test.*|*/__tests__/*|*/tests/*)
    printf '{"decision":"ask","reason":"Arquivo de teste detectado (%s). Confirme se a modificação no teste existente é intencional."}\n' "${target_path##*/}"
    ;;
  *)
    printf '{"decision":"allow"}\n'
    ;;
esac
