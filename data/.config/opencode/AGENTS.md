# Always Rule: Permission Denials & Sandbox

## Contexto
Este ambiente executa opencode dentro de um sandbox bubblewrap (ai-jail). 
`sudo *` está globalmente negado no opencode.jsonc. Muitos diretórios em 
`$HOME` são read-only montados via tmpfs. O agente NÃO tem sudo nem acesso 
de escrita irrestrito.

## Regra Obrigatória (ALWAYS)
SEMPRE que encontrar uma operação negada por:
- `sudo *` ou `chmod *` (negado/ask no opencode.jsonc)
- qualquer comando marcado como `deny` ou `ask` que precise de permissão extra
- escrita em diretório read-only (protegido pelo sandbox ou pelo tmpfs)

Você DEVE:
1. **PARE** imediatamente o que está fazendo
2. **EXPLIQUE** ao usuário exatamente o que está tentando fazer e por que precisa
3. **PASSE** o(s) comando(s) **EXATO(S)** que o usuário deve executar em outro terminal (com sudo se necessário)
4. **AGUARDE** confirmação explícita do usuário antes de continuar

## Exemplo
> "Não consigo instalar o pacote X porque precisa de sudo.
> Execute em outro terminal:
> sudo apt install X
> Me avise quando terminar para eu continuar."

## Proibições (NEVER)
- **Nunca** tente contornar a restrição (ex.: sudo via echo senha | sudo)
- **Nunca** crie fallback silencioso que muda de diretório sem avisar
- **Nunca** peça para o usuário alterar permissões permanentemente (0777, world-writable)
- **Nunca** assuma local alternativo sem confirmar com o usuário
- **Nunca** prossiga sem confirmação explícita

## Symlinks preservados no sandbox

Dentro do sandbox, symlinks cujo destino está dentro do diretório do
projeto são preservados como symlinks reais (não resolvidos).
Use `readlink` ou `ls -la` para verificá-los. Se o symlink aponta
para `$PROJECT_DIR`, o destino é writable (bind mount rw do projeto).
