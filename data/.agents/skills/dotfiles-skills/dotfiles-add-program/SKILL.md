---
name: "dotfiles-add-program"
description: "Orquestra o fluxo completo de adicionar um programa novo ao repositório de dotfiles. Executa 5 etapas na ordem: (0) detecta estado parcial, (P) pesquisa web de boas práticas e secrets específicos do programa, (1) _dotfiles-config-researcher pesquisa e mapeia configs, (2) _llm-config-guardian audita segurança, (3) @dotfiles-config-integrator integra ao repo com backup datado e validação cross-platform, (4) _dotfiles-doc-writer documenta e instala hook de pré-commit. Inclui checkpoints entre etapas para validação do usuário. Use quando o usuário disser 'quero adicionar programa X ao dotfiles', 'versionar configs do X', 'novo programa no repo', 'onboarding do X', 'adicionar X aos meus dotfiles' ou qualquer variação de trazer um programa para o controle de versão do repositório."
---

# Dotfiles Add Program v2.0 — Orquestradora

Esta skill é o ponto de entrada único para adicionar um programa ao repositório de dotfiles. Ela não faz o trabalho operacional — delega para 4 skills especializadas, na ordem correta, passando contexto entre elas.

## Quando usar

- "Quero adicionar o [programa] ao dotfiles"
- "Versionar as configs do [programa]"
- "Novo programa no repo"
- "Onboarding do [programa]"
- Qualquer variação de "adicionar programa ao controle de versão"

## Fluxo completo

```
ENTRADA: nome do programa

  ┌─────────────────────────────────────────────┐
  │  ETAPA 0 — Detectar estado atual            │
  │  (O programa já está parcialmente no repo?) │
  └──────────────────┬──────────────────────────┘
                     ▼
  ┌─────────────────────────────────────────────┐
  │  ETAPA P — Pesquisa Web (NOVA)              │
  │  Boas práticas, paths obscuros, secrets     │
  │  ► CHECKPOINT: resumo do que foi encontrado │
  └──────────────────┬──────────────────────────┘
                     ▼
  ┌─────────────────────────────────────────────┐
  │  ETAPA 1 — _dotfiles-config-researcher       │
  │  Pesquisar e mapear configs                 │
  │  ► CHECKPOINT: validar relatório            │
  └──────────────────┬──────────────────────────┘
                     ▼
  ┌─────────────────────────────────────────────┐
  │  ETAPA 2 — _llm-config-guardian              │
  │  Auditar segurança dos arquivos públicos    │
  │  ► CHECKPOINT: validar guardrails           │
  └──────────────────┬──────────────────────────┘
                     ▼
  ┌─────────────────────────────────────────────┐
  │  ETAPA 3 — @dotfiles-config-integrator       │
  │  Mover, backup datado, symlinks, .gitignore │
  │  Validação cross-platform incluída          │
  │  ► CHECKPOINT: verificar integração         │
  └──────────────────┬──────────────────────────┘
                     ▼
  ┌─────────────────────────────────────────────┐
  │  ETAPA 4 — _dotfiles-doc-writer              │
  │  Documentar, atualizar README/llms.txt      │
  │  Verificar e instalar hook de pré-commit    │
  │  ► CHECKPOINT: resumo final                 │
  └─────────────────────────────────────────────┘

SAÍDA: resumo completo do que foi feito
```

---

## Execução detalhada

### Etapa 0 — Detectar estado parcial

Antes de iniciar qualquer etapa, verifique o estado atual do programa no repositório:

```bash
# O programa já tem arquivos em data/?
ls data/*programa* data/.config/programa/ 2>/dev/null

# O programa já está em dotfile-names.list?
grep -i "programa" config/dotfile-names.list

# O programa já tem doc?
ls docs/programa.md 2>/dev/null

# O programa já tem guardrails de segurança nos configs?
grep -r "SECURITY NOTE\|DANGER ZONE\|NEVER" data/*programa* data/.config/programa/ 2>/dev/null
```

**Decisões baseadas no estado:**

| Tem em `data/`? | Tem na lista? | Tem doc? | Tem guardrails? | Ação |
|:---:|:---:|:---:|:---:|------|
| ❌ | ❌ | ❌ | ❌ | Fluxo completo (P→1→2→3→4) |
| ❌ | ✅ | ❌ | ❌ | Arquivo na lista mas sem fonte — pesquisar (P→1→2→3→4) |
| ✅ | ❌ | ❌ | ❌ | Já foi movido mas não linkado — pular etapa 1, rodar P→2→3→4 |
| ✅ | ✅ | ❌ | ❌ | Integrado mas sem auditoria — pular 1 e 3, rodar P→2→4 |
| ✅ | ✅ | ❌ | ✅ | Só falta doc — pular para etapa 4 |
| ✅ | ✅ | ✅ | ✅ | Tudo feito — informar o usuário |

Informe ao usuário o que foi detectado e quais etapas serão executadas.

---

### Etapa P — Pesquisa Web (OBRIGATÓRIA, executar antes das sub-skills)

**Por que esta etapa existe:** Boas práticas mudam, paths obscuros de configs variam por versão, e a IA pode desconhecer secrets específicos de um programa. A pesquisa web garante que a Etapa 1 receba contexto atualizado de 2025.

Execute as buscas abaixo usando a ferramenta de busca web. Adapte `[programa]` ao nome informado pelo usuário.

#### Buscas obrigatórias (sempre executar)

**P1 — Localização de configs e boas práticas de versionamento:**
```
"[programa] dotfiles config files location best practices 2025"
"[programa] config versioning symlinks git"
```

**P2 — Secrets e dados sensíveis específicos do programa:**
```
"[programa] sensitive files secrets api keys gitignore"
"[programa] credentials token dotfiles security"
```

**P3 — Paths não óbvios (cache, dados, logs que NÃO devem ir para o repo):**
```
"[programa] cache data directory exclude dotfiles"
"[programa] XDG base directory config data cache"
```

#### Buscas condicionais

**PC1 — Programa pouco documentado ou de nicho:**
*Quando:* usuário menciona ferramenta incomum (Wezterm, Aerospace, Helix, Ghostty, Yabai, etc.)
```
"[programa] config files location linux macos"
"[programa] dotfiles setup example github"
```

**PC2 — Plugin manager ou ferramentas dependentes:**
*Quando:* o programa usa plugins ou se integra com outros (ex: Neovim + Mason, Zsh + OMZ)
```
"[programa] plugin manager dotfiles versioning"
"[programa] [dependência] shared config dotfiles"
```

**PC3 — Múltiplas máquinas ou perfis por host:**
*Quando:* usuário menciona mais de uma máquina ou configurações por ambiente
```
"[programa] per-machine config host-specific dotfiles"
"[programa] dotfiles multiple profiles override"
```

**O que fazer com os resultados:**

1. **Mapear paths não óbvios** que o usuário provavelmente não mencionou (ex: `~/.local/share/[programa]/`)
2. **Identificar padrões de .gitignore** específicos do programa (ex: `*.session`, `*.lock`)
3. **Levantar riscos de secret** específicos (ex: tokens em `config.toml`, auth em `credentials.json`)
4. **Detectar dependências** que também precisam de versionar (ex: plugin manager, tema)

**CHECKPOINT:**
Apresente ao usuário um resumo antes de prosseguir:
> "A pesquisa revelou:
> - Paths encontrados: [lista]
> - Riscos de secret identificados: [lista]
> - Padrões de .gitignore recomendados: [lista]
> - Dependências a considerar: [lista]
> Posso prosseguir com o mapeamento detalhado?"

**Dados a repassar para a Etapa 1:**
- Lista de paths a verificar (incluindo os não óbvios)
- Padrões de .gitignore específicos do programa
- Riscos de secret mapeados

---

### Etapa 1 — Pesquisa (`_dotfiles-config-researcher`)

Leia a skill `_dotfiles-config-researcher` e execute-a com o nome do programa, enriquecendo o input com o resultado da Etapa P.

**Input para a skill:**
- Nome do programa fornecido pelo usuário
- Paths adicionais descobertos na Etapa P
- Riscos de secret da Etapa P (para atenção reforçada)

**Output esperado:**
- Relatório com paths, classificação de arquivos (público/sensível/gerado), dependências, boas práticas

**CHECKPOINT:**
Apresente o relatório ao usuário e pergunte:
> "Este é o mapeamento dos configs do [programa]. Está correto? Quer ajustar algo antes de continuar com a auditoria de segurança?"

**Dados a repassar para a próxima etapa:**
- Lista de arquivos classificados como **público** (serão auditados na etapa 2)
- Lista de arquivos classificados como **sensível** (serão tratados na etapa 3)
- Dependências identificadas (serão documentadas na etapa 4)

---

### Etapa 2 — Auditoria de segurança (`_llm-config-guardian`)

Leia a skill `_llm-config-guardian` e execute-a nos arquivos **públicos** identificados na etapa 1.

**Input para a skill:**
- Cada arquivo de configuração classificado como "público"
- Riscos de secret mapeados na Etapa P (reforçar verificação nesses pontos)

**Output esperado:**
- Arquivos anotados com comentários `SECURITY NOTE`, `DANGER ZONE`, `NEVER`
- Verificação do `.gitignore` para arquivos sensíveis (incluindo padrões da Etapa P)
- Recomendações de permissões de arquivo

**CHECKPOINT:**
Apresente os guardrails aplicados ao usuário:
> "Os seguintes guardrails de segurança foram aplicados: [lista]. Os configs estão protegidos. Quer revisar antes de integrar ao repositório?"

**Dados a repassar para a próxima etapa:**
- Arquivos públicos auditados (prontos para mover)
- Padrões de `.gitignore` recomendados (da Etapa P + descobertos aqui)
- Recomendações de permissão

---

### Etapa 3 — Integração (`@dotfiles-config-integrator`)

Leia a skill `@dotfiles-config-integrator` e execute-a com os dados das etapas anteriores.

**Input para a skill:**
- Arquivos públicos auditados (da etapa 2)
- Arquivos sensíveis identificados (da etapa 1)
- Padrões de `.gitignore` recomendados (da etapa 2)

**Output esperado:**
- Arquivos movidos para `data/` **com backup datado obrigatório antes de mover**
- Symlinks criados de forma idempotente
- `config/dotfile-names.list` atualizado
- `.gitignore` atualizado com todos os padrões
- Arquivos `.example` criados para sensíveis

#### Regras de integração obrigatórias (herdadas da dotfiles-manager)

**Backup datado antes de qualquer movimentação:**
```bash
# Sempre fazer backup antes de mover ou substituir
make_symlink() {
  local src="$1" dst="$2"

  # Backup se arquivo real existir (não symlink)
  if [[ -e "$dst" && ! -L "$dst" ]]; then
    local backup="${dst}.bak.$(date +%Y%m%d_%H%M%S)"
    mv "$dst" "$backup"
    echo "  ↳ backup: $backup"
  fi

  # Remover symlink antigo quebrado
  [[ -L "$dst" ]] && rm "$dst"

  # Criar diretório pai se necessário
  mkdir -p "$(dirname "$dst")"

  ln -s "$src" "$dst"
  echo "  ✓ $dst → $src"
}
```

**Validação cross-platform antes de executar comandos:**

Detecte o OS atual e aplique os comandos corretos:

```bash
detect_os() {
  case "$(uname -s)" in
    Linux*)
      if grep -qi microsoft /proc/version 2>/dev/null; then
        echo "wsl"
      else
        echo "linux"
      fi
      ;;
    Darwin*) echo "macos" ;;
    *)       echo "unknown" ;;
  esac
}
```

| Comando | Linux | macOS | WSL |
|---------|-------|-------|-----|
| `ln -s` | ✓ | ✓ | ✓* |
| `readlink -f` | ✓ | ✗** | ✓ |
| `stat -c %a` | ✓ | ✗*** | ✓ |
| `sed -i ''` | ✗ | ✓ | ✗ |

\* WSL: symlinks para `/mnt/c/` têm limitações  
\** macOS: usar `greadlink` (coreutils) ou `realpath`  
\*** macOS: usar `stat -f %p`

**Idempotência obrigatória:**
- Checar se o symlink já existe antes de criar: `[[ -L "$dst" ]] && continue`
- Checar se o arquivo já está em `data/` antes de mover
- Nunca sobrescrever `.gitignore` — sempre **append** de novos padrões

**CHECKPOINT:**
Mostre o estado final:
> "Integração concluída:
> - [N] arquivo(s) movido(s) para data/ (backups em: [paths])
> - [N] symlink(s) criado(s)
> - [N] entrada(s) adicionada(s) a dotfile-names.list
> - [N] padrão(ões) adicionado(s) ao .gitignore
> - OS detectado: [linux/macos/wsl] — comandos compatíveis usados
> Quer revisar antes de documentar?"

---

### Etapa 4 — Documentação e Hook (`_dotfiles-doc-writer`)

Leia a skill `_dotfiles-doc-writer` e execute-a com todo o contexto acumulado. Em seguida, verifique e instale o hook de pré-commit.

**Input para a skill:**
- Relatório do `_dotfiles-config-researcher` (etapa 1)
- Guardrails do `_llm-config-guardian` (etapa 2)
- Estado da integração do `@dotfiles-config-integrator` (etapa 3)
- Resumo da Etapa P (boas práticas, riscos, dependências)

**Output esperado:**
- `docs/[programa].md` criado
- `README.md` atualizado
- `llms.txt` atualizado
- Padrões registrados no `_knowledge-manager`

#### Verificação e instalação do hook de pré-commit (NOVA)

Após a documentação, verifique se o hook de detecção de secrets está instalado:

```bash
# Verificar se o hook já existe
if [[ -x ".git/hooks/pre-commit" ]]; then
  echo "✓ Hook de pré-commit já instalado."
else
  echo "⚠️  Hook de pré-commit não encontrado. Instalando..."

  cat > .git/hooks/pre-commit << 'EOF'
#!/usr/bin/env bash
set -euo pipefail

STAGED=$(git diff --cached --name-only)
FOUND=0

for file in $STAGED; do
  [[ -f "$file" ]] || continue
  if grep -qEi '(api[_-]?key\s*=|secret\s*=|password\s*=|-----BEGIN|AWS_SECRET|GITHUB_TOKEN|PRIVATE_KEY)' "$file"; then
    echo "🔴 BLOQUEADO: possível secret em '$file'"
    FOUND=1
  fi
done

[[ $FOUND -eq 1 ]] && echo "Remova os secrets antes de commitar." && exit 1
exit 0
EOF

  chmod +x .git/hooks/pre-commit
  echo "✓ Hook de pré-commit instalado em .git/hooks/pre-commit"
fi
```

Informe ao usuário se o hook já existia ou se foi instalado agora.

**FINALIZAÇÃO:**
Apresente o resumo final:

```markdown
## ✅ Onboarding do [programa] concluído

### Etapa P — Pesquisa Web
- Paths não óbvios descobertos: [lista ou "nenhum"]
- Riscos de secret mapeados: [lista]
- Padrões de .gitignore adicionados: [lista]
- Dependências detectadas: [lista ou "nenhuma"]

### Etapa 1 — Pesquisa de Configs
- [N] arquivo(s) mapeado(s): [N] público(s), [N] sensível(is), [N] gerado(s)
- Segue XDG: sim/não
- Plugin manager: [nome] ou nenhum

### Etapa 2 — Segurança
- [N] guardrail(s) aplicado(s)
- .gitignore: [N] padrão(ões) adicionado(s)

### Etapa 3 — Integração
- OS detectado: [linux/macos/wsl]
- Arquivos em data/: [lista]
- Backups criados: [lista de .bak.TIMESTAMP ou "nenhum"]
- Symlinks em ~/: [lista]
- dotfile-names.list: atualizado

### Etapa 4 — Documentação e Hook
- docs/[programa].md: criado
- README.md: atualizado
- llms.txt: atualizado
- Base de conhecimento: [N] padrão(ões) registrado(s)
- Hook de pré-commit: [instalado agora / já existia]

### Próximo passo
Faça o commit das mudanças com uma mensagem descritiva:
`git add . && git commit -m "feat([programa]): add program to dotfiles"`
```

---

## Regras da orquestradora

1. **Nunca pular a Etapa P** — a pesquisa web garante contexto atualizado que a IA pode não ter
2. **Nunca pular etapa** — o `_dotfiles-config-researcher` precisa do output da Etapa P; o `_llm-config-guardian` precisa do output da Etapa 1
3. **Checkpoint obrigatório** — o usuário valida antes de seguir para a próxima etapa
4. **Contexto passa adiante** — cada etapa recebe o output acumulado de todas as anteriores
5. **Detecta estado parcial** — a etapa 0 evita retrabalho e duplicação
6. **Não executa operações diretamente** — delega para as skills especializadas
7. **Backup sempre** — nunca mover arquivo sem criar `.bak.TIMESTAMP` antes
8. **Cross-platform** — sempre detectar OS e usar comandos compatíveis
9. **Hook de pré-commit** — verificar e instalar ao final de todo onboarding
10. **Apresenta resumo final** — o usuário sabe exatamente o que foi feito em cada etapa
