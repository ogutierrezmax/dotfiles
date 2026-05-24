# Ranking de Importância — Skills `dotfiles*`

> Análise das 6 skills do ecossistema de dotfiles, classificadas por criticidade,
> dependências e impacto na integridade do repositório.

---

## Tier 1 — Críticas (fundação do ecossistema)

### 1. `dotfiles-manager` ⭐⭐⭐⭐⭐

**Função:** Gerencia dotfiles com segurança, portabilidade cross-platform e versionamento Git — bootstrap, rollback, detecção de secrets e validação de symlinks.

Skill mais completa e autossuficiente. Estabelece as bases de todo o sistema:
- Segurança (detecção de secrets, .gitignore, hooks pre-commit)
- Estrutura de repositório recomendada
- Bootstrap cross-platform com idempotência
- Rollback seguro com backup datado
- Validação e saúde dos symlinks
- Regras absolutas que todas as outras skills herdam

**Sem esta skill:** não há base segura para gerenciar dotfiles.

---

### 2. `dotfiles-add-program` ⭐⭐⭐⭐⭐

**Função:** Orquestra o fluxo completo de onboarding de um programa no repositório — pesquisa, mapeamento, auditoria de segurança, integração e documentação.

Orquestradora central do pipeline de onboarding. Coordena 4 skills especializadas:
1. `dotfiles-config-researcher` — mapeamento
2. `llm-config-guardian` — auditoria de segurança
3. `dotfiles-config-integrator` — integração técnica
4. `dotfiles-doc-writer` — documentação

Inclui pesquisa web (Etapa P), checkpoints com o usuário, backup datado e
validação cross-platform. É o ponto de entrada único para adicionar qualquer
programa ao repositório.

**Sem esta skill:** não há fluxo padronizado de onboarding.

---

## Tier 2 — Operacionais (pipeline de onboarding)

### 3. `dotfiles-config-researcher` ⭐⭐⭐⭐

**Função:** Pesquisa e mapeia todos os arquivos de configuração de um programa, classificando cada um como público, sensível ou gerado.

Etapa de inteligência. Pesquisa online + inspeção local para mapear todos os
arquivos de configuração de um programa e classificá-los em:
- **público** → versionar em `data/`
- **sensível** → excluir, criar `.example`
- **gerado** → ignorar completamente

É read-only (não modifica nada), o que reduz risco. Sem ela, as skills
seguintes operam sem direção.

**Sem esta skill:** onboarding cego, risco de versionar secrets ou perder configs.

---

### 4. `dotfiles-secure-commit` ⭐⭐⭐⭐

**Função:** Executa commits seguros com auditoria de secrets, staging inteligente e mensagens no padrão Conventional Commits.

Última barreira de segurança antes do commit. Audita o diff em 5 categorias de
risco, bloqueia secrets, gera mensagens no formato Conventional Commits e exige
assinatura `Verified-By: dotfiles-secure-commit` no rodapé.

Crucial para evitar vazamento de credenciais em um repositório que, por natureza,
gerencia arquivos sensíveis do home directory.

**Sem esta skill:** toda a segurança das skills anteriores pode ser contornada
por um commit descuidado.

---

## Tier 3 — Táticas (execução)

### 5. `dotfiles-config-integrator` ⭐⭐⭐

**Função:** Integra tecnicamente as configurações de um programa ao repositório — move arquivos para `data/`, cria symlinks, atualiza `dotfile-names.list` e `.gitignore`.

Execução técnica: move arquivos para `data/`, cria symlinks, atualiza
`dotfile-names.list` e `.gitignore`. Puramente mecânico — depende do researcher
(sabe o que mover) e do guardian (sabe o que é seguro).

Baixo risco de decisão errada, mas essencial para materializar o onboarding.

**Sem esta skill:** os configs ficam mapeados mas nunca são integrados ao repo.

---

### 6. `dotfiles-doc-writer` ⭐⭐

**Função:** Cria e mantém a documentação de programas no repositório — `docs/[programa].md`, README.md, `llms.txt` e registros na base de conhecimento.

Documentação: cria `docs/[programa].md` seguindo template padronizado, atualiza
README.md e `llms.txt`, registra padrões no knowledge-manager.

Valor tangível para manutenibilidade e contexto para agentes de IA, mas não
afeta a integridade ou funcionamento do repositório. Pode ser executado a
qualquer momento.

**Sem esta skill:** o repositório funciona perfeitamente, apenas fica menos
documentado.

---

## Diagrama de Dependências

```
dotfiles-add-program (orquestrador)
  ├── dotfiles-config-researcher  ← pesquisa (não depende de ninguém)
  ├── llm-config-guardian          ← depende do researcher
  ├── dotfiles-config-integrator   ← depende do guardian
  └── dotfiles-doc-writer          ← depende do integrator

dotfiles-manager          ← independente, visão macro
dotfiles-secure-commit    ← independente, usada no final do ciclo
```

## Relações entre as skills

| Skill | Papel | Depende de | Afetada por |
|-------|-------|------------|-------------|
| `dotfiles-manager` | Fundação | Nada | Nada |
| `dotfiles-add-program` | Orquestrador | `dotfiles-manager` (herda regras) | Todas as sub-skills |
| `dotfiles-config-researcher` | Inteligência | Nada | Nada |
| `dotfiles-secure-commit` | Segurança | Nada | Nada |
| `dotfiles-config-integrator` | Execução | Researcher + Guardian | Mudanças no repo |
| `dotfiles-doc-writer` | Documentação | Integrator | Mudanças no repo |

## Resumo

- **Tier 1** → `dotfiles-manager` + `dotfiles-add-program`: o cérebro e o core.
  Sem eles, as skills operacionais não têm contexto nem orquestração.
- **Tier 2** → `dotfiles-config-researcher` + `dotfiles-secure-commit`:
  inteligência e segurança. Determinam o que fazer e garantem que seja feito
  com segurança.
- **Tier 3** → `dotfiles-config-integrator` + `dotfiles-doc-writer`:
  execução e documentação. Valor importante mas substituível/diferível.
