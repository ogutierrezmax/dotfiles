---
name: dotfiles-add-program
description: "Orquestra o fluxo completo de adicionar um programa novo ao repositório de dotfiles. Executa 4 etapas na ordem: (1) dotfiles-config-researcher pesquisa e mapeia configs, (2) llm-config-guardian audita segurança, (3) dotfiles-config-integrator integra ao repo, (4) dotfiles-doc-writer documenta. Inclui checkpoints entre etapas para validação do usuário e detecção de estado parcial para programas já parcialmente adicionados. Use quando o usuário disser 'quero adicionar programa X ao dotfiles', 'versionar configs do X', 'novo programa no repo', 'onboarding do X', 'adicionar X aos meus dotfiles' ou qualquer variação de trazer um programa para o controle de versão do repositório."
---

# Dotfiles Add Program — Orquestradora

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
  │  ETAPA 1 — dotfiles-config-researcher       │
  │  Pesquisar e mapear configs                 │
  │  ► CHECKPOINT: validar relatório            │
  └──────────────────┬──────────────────────────┘
                     ▼
  ┌─────────────────────────────────────────────┐
  │  ETAPA 2 — llm-config-guardian              │
  │  Auditar segurança dos arquivos públicos    │
  │  ► CHECKPOINT: validar guardrails           │
  └──────────────────┬──────────────────────────┘
                     ▼
  ┌─────────────────────────────────────────────┐
  │  ETAPA 3 — dotfiles-config-integrator       │
  │  Mover, symlinks, listas, .gitignore        │
  │  ► CHECKPOINT: verificar integração         │
  └──────────────────┬──────────────────────────┘
                     ▼
  ┌─────────────────────────────────────────────┐
  │  ETAPA 4 — dotfiles-doc-writer              │
  │  Documentar, atualizar README/llms.txt      │
  │  ► CHECKPOINT: resumo final                 │
  └─────────────────────────────────────────────┘

SAÍDA: resumo completo do que foi feito
```

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
| ❌ | ❌ | ❌ | ❌ | Fluxo completo (etapas 1→4) |
| ❌ | ✅ | ❌ | ❌ | Arquivo na lista mas sem fonte — pesquisar (etapa 1→4) |
| ✅ | ❌ | ❌ | ❌ | Já foi movido mas não linkado — pular etapa 1, rodar 2→4 |
| ✅ | ✅ | ❌ | ❌ | Integrado mas sem auditoria — pular 1 e 3, rodar 2→4 |
| ✅ | ✅ | ❌ | ✅ | Só falta doc — pular para etapa 4 |
| ✅ | ✅ | ✅ | ✅ | Tudo feito — informar o usuário |

Informe ao usuário o que foi detectado e quais etapas serão executadas.

### Etapa 1 — Pesquisa (`dotfiles-config-researcher`)

Leia a skill `dotfiles-config-researcher` e execute-a com o nome do programa.

**Input para a skill:**
- Nome do programa fornecido pelo usuário

**Output esperado:**
- Relatório com paths, classificação de arquivos, dependências, boas práticas

**CHECKPOINT:**
Apresente o relatório ao usuário e pergunte:
> "Este é o mapeamento dos configs do [programa]. Está correto? Quer ajustar algo antes de continuar com a auditoria de segurança?"

**Dados a repassar para a próxima etapa:**
- Lista de arquivos classificados como **público** (serão auditados na etapa 2)
- Lista de arquivos classificados como **sensível** (serão tratados na etapa 3)
- Dependências identificadas (serão documentadas na etapa 4)

### Etapa 2 — Auditoria de segurança (`llm-config-guardian`)

Leia a skill `llm-config-guardian` e execute-a nos arquivos **públicos** identificados na etapa 1.

**Input para a skill:**
- Cada arquivo de configuração classificado como "público"

**Output esperado:**
- Arquivos anotados com comentários `SECURITY NOTE`, `DANGER ZONE`, `NEVER`
- Verificação do `.gitignore` para arquivos sensíveis
- Recomendações de permissões de arquivo

**CHECKPOINT:**
Apresente os guardrails aplicados ao usuário:
> "Os seguintes guardrails de segurança foram aplicados: [lista]. Os configs estão protegidos. Quer revisar antes de integrar ao repositório?"

**Dados a repassar para a próxima etapa:**
- Arquivos públicos auditados (prontos para mover)
- Padrões de `.gitignore` recomendados
- Recomendações de permissão

### Etapa 3 — Integração (`dotfiles-config-integrator`)

Leia a skill `dotfiles-config-integrator` e execute-a com os dados das etapas anteriores.

**Input para a skill:**
- Arquivos públicos auditados (da etapa 2)
- Arquivos sensíveis identificados (da etapa 1)
- Padrões de `.gitignore` recomendados (da etapa 2)

**Output esperado:**
- Arquivos movidos para `data/`
- Symlinks criados
- `config/dotfile-names.list` atualizado
- `.gitignore` atualizado
- Arquivos `.example` criados para sensíveis

**CHECKPOINT:**
Mostre o estado final:
> "Integração concluída:
> - [N] arquivo(s) movido(s) para data/
> - [N] symlink(s) criado(s)
> - [N] entrada(s) adicionada(s) a dotfile-names.list
> - [N] padrão(ões) adicionado(s) ao .gitignore
> Quer revisar antes de documentar?"

### Etapa 4 — Documentação (`dotfiles-doc-writer`)

Leia a skill `dotfiles-doc-writer` e execute-a com todo o contexto acumulado.

**Input para a skill:**
- Relatório do `dotfiles-config-researcher` (etapa 1)
- Guardrails do `llm-config-guardian` (etapa 2)
- Estado da integração do `dotfiles-config-integrator` (etapa 3)

**Output esperado:**
- `docs/[programa].md` criado
- `README.md` atualizado
- `llms.txt` atualizado
- Padrões registrados no `knowledge-manager`

**FINALIZAÇÃO:**
Apresente o resumo final:

```markdown
## ✅ Onboarding do [programa] concluído

### Etapa 1 — Pesquisa
- [N] arquivo(s) mapeado(s): [N] público(s), [N] sensível(is), [N] gerado(s)
- Segue XDG: sim/não
- Plugin manager: [nome] ou nenhum

### Etapa 2 — Segurança
- [N] guardrail(s) aplicado(s)
- .gitignore: [N] padrão(ões) adicionado(s)

### Etapa 3 — Integração
- Arquivos em data/: [lista]
- Symlinks em ~/: [lista]
- dotfile-names.list: atualizado

### Etapa 4 — Documentação
- docs/[programa].md: criado
- README.md: atualizado
- llms.txt: atualizado
- Base de conhecimento: [N] padrão(ões) registrado(s)

### Próximo passo
Faça o commit das mudanças com uma mensagem descritiva.
```

## Regras da orquestradora

1. **Nunca pular etapa** — se o `dotfiles-config-researcher` não rodou, o `llm-config-guardian` não recebe input válido
2. **Checkpoint obrigatório** — o usuário valida antes de seguir para a próxima etapa
3. **Contexto passa adiante** — cada etapa recebe o output acumulado de todas as anteriores
4. **Detecta estado parcial** — a etapa 0 evita retrabalho e duplicação
5. **Não executa operações diretamente** — delega para as skills especializadas
6. **Apresenta resumo final** — o usuário sabe exatamente o que foi feito em cada etapa
