---
tags: [security, dotfiles, best-practices, secrets]
type: concept
---

# 🛡️ Princípios de Segurança em Dotfiles

Este documento estabelece a lógica sistêmica para manter um repositório de dotfiles seguro, evitando o vazamento de informações sensíveis e garantindo a integridade do ambiente.

## 🧠 Lógica Sistêmica

O maior risco em repositórios de dotfiles é o **Over-sharing** (compartilhamento excessivo). A segurança deve ser baseada na separação clara entre *estrutura* (pública/versionada) e *dados sensíveis* (privados/locais).

### 1. Separação de Contextos
A estratégia recomendada é o uso de "arquivos sombra" ou inclusões locais:
- **Padrão:** O arquivo versionado (ex: `.zshrc`) deve carregar um arquivo não versionado (ex: `.zshrc.local`) se ele existir.
- **Vantagem:** Permite manter configurações específicas da máquina e tokens de API fora do controle de versão.

### 2. Guardrails para IA (Agent-Ready)
Com o aumento do uso de agentes de IA (como este que você está usando agora), é crucial marcar visualmente as zonas de perigo no código:
- **Metadados Inline:** Comentários estruturados que servem como "tags de segurança" para a IA.
- **Exemplo:** `### SECURITY NOTE: Do not move this export to a public file`.

### 3. Sanitização Preventiva
Antes de cada commit, o usuário/agente deve verificar:
- [ ] Existência de chaves `sk-`, `ghp_`, `export KEY=`, etc.
- [ ] Permissões de diretórios críticos (`.ssh`, `.gnupg`).
- [ ] Presença de histórico de comandos (`.bash_history`, `.zsh_history`) em locais indesejados.

> [!TIP]
> Use o arquivo `.gitignore` de forma agressiva. É melhor ignorar algo por engano e ter que forçar o add do que vazar um segredo.

---
*Este conhecimento foi extraído durante a estruturação da pasta de documentação de segurança em 2026-04-26.*
