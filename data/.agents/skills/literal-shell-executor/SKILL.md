---
name: literal-shell-executor
description: Executa o restante de uma solicitação /shell como um comando literal
  do shell. Use apenas quando o usuário invocar explicitamente /shell e desejar que
  o texto seguinte seja executado diretamente no terminal.
disable-model-invocation: true
---
# Run Shell Commands

Use this skill only when the user explicitly invokes `/shell`.

## Behavior

1. Treat all user text after the `/shell` invocation as the literal shell command to run.
2. Execute that command immediately with the terminal tool.
3. Do not rewrite, explain, or "improve" the command before running it.
4. Do not inspect the repository first unless the command itself requires repository context.
5. If the user invokes `/shell` without any following text, ask them which command to run.

## Response

- Run the command first.
- Then briefly report the exit status and any important stdout or stderr.
