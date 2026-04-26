---
name: dotfiles-doc-writer
description: "Documenta um programa recém-adicionado ao repositório de dotfiles: cria docs/[programa].md seguindo o template padrão do repo (baseado no tmux.md existente), atualiza a seção 'Documentação de Ferramentas' do README.md, atualiza llms.txt com contexto do novo programa, e chama o knowledge-manager para registrar padrões sistêmicos. Use após o dotfiles-config-integrator ter integrado os configs, ou quando o usuário quiser documentar um programa que já está no repo mas sem documentação."
---

# Dotfiles Doc Writer

Cria e mantém a documentação de programas no repositório de dotfiles. Garante que cada programa versionado tenha um doc padronizado, que o README e o `llms.txt` estejam atualizados, e que padrões aprendidos sejam registrados na base de conhecimento.

## Quando usar

- Após o `dotfiles-config-integrator` ter integrado um programa ao repo
- Quando um programa já está no repo mas não tem doc em `docs/`
- Quando o usuário pede para documentar um programa

## Processo

### 1. Criar `docs/[programa].md`

Crie o arquivo de documentação seguindo **exatamente** o template abaixo. Este template é baseado no padrão já estabelecido pelo `docs/tmux.md` existente no repositório.

**Template obrigatório:**

```markdown
# [emoji] [Nome do Programa] ([categoria])

> [Uma frase descrevendo o propósito do programa no contexto dos dotfiles]

Este documento detalha a configuração atual do `[programa]`, [breve descrição de como é gerenciado].

## 🛠 Tech Stack
- **[Tipo]**: [programa]
- **[Dependência]**: [nome e link]
- **[Outra dependência]**: [nome e link]

## ⚡ Configuração Atual (`[path do config]`)

[Descrição do que a configuração faz]

```[linguagem do config]
[Conteúdo relevante do config — NÃO copiar o arquivo inteiro,
apenas as seções mais importantes e educativas]
```

## 🗺 Estrutura de Arquivos
- `[path]`: [propósito]
- `[path]`: [propósito]

## 🔒 Segurança
- **Arquivos versionados**: [lista dos arquivos em data/]
- **Arquivos excluídos**: [lista dos sensíveis/gerados e por quê]
- **Guardrails aplicados**: [quais comentários SECURITY NOTE/DANGER ZONE foram adicionados]

## 🚀 Como instalar (Manual)

1. **Instale o programa**:
   ```bash
   sudo apt install [programa]
   ```
2. **[Passo de setup]**:
   ```bash
   [comando]
   ```
3. **Ative os symlinks**:
   ```bash
   ./dotfiles-menu.sh
   # Selecione o número correspondente ao [programa]
   ```

## 📖 [Seção específica do programa]

[Conteúdo relevante — plugins, keybindings, customizações, etc.]

---
*Este documento foi gerado durante o onboarding do [programa] nos dotfiles.*
```

**Regras do template:**
- O emoji do título deve ser relevante ao programa (🪟 para multiplexers, ✏️ para editores, 🐚 para shells, etc.)
- A seção de configuração NÃO deve copiar o arquivo inteiro — apenas as partes mais educativas
- A seção de segurança é obrigatória mesmo que o programa não tenha nada sensível (nesse caso, dizer explicitamente "nenhum arquivo sensível identificado")
- O "Como instalar" deve incluir TODOS os passos, incluindo dependências e plugin managers

### 2. Atualizar `README.md`

Adicione o novo programa à seção "Documentação de Ferramentas" do README.md.

**Localização**: a seção `## 📖 Documentação de Ferramentas` do README. Atualmente contém:

```markdown
## 📖 Documentação de Ferramentas

Confira os guias detalhados sobre as ferramentas gerenciadas por estes dotfiles:

- [🪟 Tmux (Terminal Multiplexer)](./docs/tmux.md): Configuração de persistência e plugins.
```

**Adicionar uma nova linha** seguindo o mesmo formato:
```markdown
- [emoji Nome do Programa (Categoria)](./docs/programa.md): Descrição curta.
```

Use a skill `seamless-integration` mentalmente — a nova linha deve parecer que sempre esteve ali. Mantenha ordem alfabética ou por categoria se houver muitos itens.

### 3. Atualizar `llms.txt`

O `llms.txt` serve como mapa para agentes de IA. Adicione contexto sobre o novo programa.

**Localização**: seção `## Estrutura de Arquivos Críticos` ou uma nova seção `## Programas Gerenciados`.

**Formato de adição:**
```
- `data/[path-do-programa]`: Configurações do [programa] — [o que contém em uma frase].
```

Se o programa tiver particularidades que um agente de IA deveria saber (ex: "não editar a última linha do tmux.conf"), adicione na seção de convenções.

### 4. Registrar na base de conhecimento

Chame internamente a skill `knowledge-manager` para registrar padrões sistêmicos aprendidos durante o onboarding deste programa.

**Exemplos de padrões a registrar:**
- "O programa X segue XDG por padrão, configs em `~/.config/x/`"
- "O programa X usa o plugin manager Y, que precisa ser clonado manualmente"
- "O programa X tem arquivo de credenciais em path Z — sempre excluir do versionamento"
- "O programa X gera cache em path W — nunca versionar"

O `knowledge-manager` decide o formato e local de armazenamento (geralmente `.devtool/knowledge/`).

## Regras

- **SEMPRE siga o template** — consistência visual com o `tmux.md` existente é obrigatória
- **NUNCA copie o config inteiro** no doc — selecione as partes educativas
- **SEMPRE inclua a seção de Segurança** — mesmo que vazia (dizer "nenhum risco identificado")
- **SEMPRE atualize os 3 arquivos**: `docs/programa.md`, `README.md` e `llms.txt`
- **SEMPRE chame o knowledge-manager** ao final — não é opcional
