# Always Rule: Permission Denials & Sandbox

## Detecção de modo de execução (JAIL vs HOST)

O opencode pode rodar **dentro** do sandbox bubblewrap (ai-jail) ou **direto no host**
(`ai-jail --no-jail`). As regras abaixo dependem do modo — detecte antes de agir.

**Comando canônico de detecção:**

```bash
echo "$RUNNING_INSIDE_SANDBOX"; hostname
```

- `RUNNING_INSIDE_SANDBOX=true` (ou `hostname` == `ai-sandbox`, fallback p/ sessões antigas)
  → **modo JAIL**, aplique as regras estritas da seção "Always Rule".
- `RUNNING_INSIDE_SANDBOX=false` (ou ausente) → **modo HOST**, aplique as regras flexíveis
  da seção "Modo HOST (--no-jail)".

Por segurança, se houver **qualquer indício** de jail (hostname `ai-sandbox`, variável
`true`, `$HOME` em tmpfs) e os sinais divergirem, trate como **JAIL** — nunca relaxe a
segurança por ambiguidade.

## Modo HOST (--no-jail) — regras flexíveis

Quando rodando direto no host (`--no-jail`, tipicamente com `--auto`), o usuário espera
que a IA execute modificações e instalações diretamente. Nesse modo:

- Pode editar arquivos, instalar pacotes (`sudo apt install ...`), reiniciar serviços
  e aplicar mudanças **sem pedir confirmação a cada passo**.
- Se o usuário fornecer a senha na conversa, pode usar `echo "senha" | sudo -S <cmd>`
  diretamente.
- Mantém-se o bom senso: rodar lint/testes ao final; **não** commitar segredos;
  **não** `rm -rf *` (permanece `deny`); **não** destruição irreversível sem aviso prévio.

## Contexto
Este ambiente executa opencode dentro de um sandbox bubblewrap (ai-jail).
`sudo *` pode ser habilitado via `opencode.json` com `"bash": { "sudo *": "allow" }`.
Muitos diretórios em `$HOME` são read-only montados via tmpfs.

## Regra Obrigatória (ALWAYS) — aplica ao modo JAIL

SEMPRE que encontrar uma operação negada por:
- qualquer comando marcado como `deny` ou `ask` que precise de permissão extra
- escrita em diretório read-only (protegido pelo sandbox ou pelo tmpfs)

Você DEVE:
1. **PARE** imediatamente o que está fazendo
2. **EXPLIQUE** ao usuário exatamente o que está tentando fazer e por que precisa
3. **PASSE** o(s) comando(s) **EXATO(S)** que o usuário deve executar em outro terminal
4. **AGUARDE** confirmação explícita do usuário antes de continuar

## Exemplo
> "Não consigo instalar o pacote X porque precisa de sudo.
> Execute em outro terminal:
> sudo apt install X
> Me avise quando terminar para eu continuar."

## Proibições (NEVER) — aplica ao modo JAIL
- **Nunca** tente contornar a restrição via `echo senha | sudo` (no modo JAIL; no modo HOST é permitido com autorização)
- **Nunca** crie fallback silencioso que muda de diretório sem avisar
- **Nunca** peça para o usuário alterar permissões permanentemente (0777, world-writable)
- **Nunca** assuma local alternativo sem confirmar com o usuário
- **Nunca** prossiga sem confirmação explícita

## Symlinks preservados no sandbox

Dentro do sandbox, symlinks cujo destino está dentro do diretório do
projeto são preservados como symlinks reais (não resolvidos).
Use `readlink` ou `ls -la` para verificá-los. Se o symlink aponta
para `$PROJECT_DIR`, o destino é writable (bind mount rw do projeto).

## Exceção
