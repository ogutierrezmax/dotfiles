---
name: "dotfiles-add-program"
description: "Orquestra a inclusão de um programa nos dotfiles: detecta o estado existente, coordena pesquisa, auditoria, integração e documentação, evitando retrabalho. Use quando o usuário quiser adicionar ou versionar configurações de um programa no repositório de dotfiles."
---

# Dotfiles Add Program — Orquestradora

Esta skill é o ponto de entrada único para adicionar um programa ao repositório de dotfiles. Ela não faz o trabalho operacional — delega para 4 skills especializadas, na ordem correta, passando contexto entre elas.

## Quando usar

- "Quero adicionar o [programa] ao dotfiles"
- "Versionar as configs do [programa]"
- "Novo programa no repo"
- "Onboarding do [programa]"
- Qualquer variação de "adicionar programa ao controle de versão"

## Fluxo

```
ENTRADA: nome do programa

ETAPA 1: Detectar estado atual
ETAPA 2: Pesquisar e mapear configurações (_dotfiles-config-researcher)
ETAPA 3: Auditar segurança (_llm-config-guardian)
ETAPA 4: Integrar (@dotfiles-config-integrator)
ETAPA 5: Documentar (_dotfiles-doc-writer)
SAÍDA: resumo completo do que foi feito
```

---

## Execução detalhada

### Etapa 1 — Detectar o estado

Inspecione somente os locais e artefatos relevantes ao programa: configurações locais, `data/`, `config/dotfile-names.list`, documentação existente e `.gitignore`. Use `dotfiles-lib.sh` ou as ferramentas existentes do repositório para determinar o estado dos links; não replique a lógica da biblioteca.

Resuma o que já existe e quais lacunas restam. Reuse resultados válidos de pesquisas, auditorias ou integrações anteriores. Se tudo estiver concluído, informe isso e encerre sem repetir etapas.

---

### Etapa 2 — Pesquisar e mapear (`_dotfiles-config-researcher`)

Delegue a pesquisa online e a inspeção local ao `_dotfiles-config-researcher` em uma única passagem. Passe o nome do programa, o estado encontrado na Etapa 1 e qualquer contexto de plataforma ou dependência informado pelo usuário. Pesquise pontos específicos que permaneçam incertos; não execute uma bateria fixa de buscas antes da skill.

Use o relatório da skill para distinguir arquivos públicos, sensíveis e gerados, além de registrar dependências e exclusões relevantes. A pesquisa é somente leitura.

Apresente um resumo do mapeamento. Peça confirmação antes de integrar apenas quando houver ambiguidade relevante, risco de dados sensíveis ou uma alteração que possa substituir dados locais; caso contrário, prossiga e registre as premissas no resumo final.

---

### Etapa 3 — Auditar segurança (`_llm-config-guardian`)

Execute a auditoria nos arquivos que podem ser versionados, considerando os riscos e exclusões apontados pela pesquisa. Aplique comentários de segurança somente quando forem compatíveis com o formato e úteis no contexto. Nunca versionize credenciais; repasse ao integrador os padrões de exclusão e as recomendações de permissões.

---

### Etapa 4 — Integrar (`@dotfiles-config-integrator`)

Delegue a integração à skill especializada, passando o relatório de pesquisa, os resultados da auditoria, os arquivos a incluir ou excluir e o estado local. Ela deve seguir as APIs e convenções do repositório, preservar dados existentes com backup antes de substituí-los e verificar o resultado. Não replique aqui comandos de movimentação, criação de links ou diferenças entre sistemas operacionais.

### Etapa 5 — Documentar (`_dotfiles-doc-writer`)

Delegue a documentação com o relatório, as decisões de segurança e o resultado da integração. Siga os padrões e artefatos já adotados pelo repositório; não crie índices ou automações locais novos apenas por causa deste onboarding. Instalação ou alteração de hooks é uma tarefa independente.

**FINALIZAÇÃO:**

Resuma o que foi encontrado e alterado, incluindo arquivos adicionados ou excluídos, backups, validações executadas e pendências. Não faça commit nem use `git add .`; deixe o staging e o commit para uma solicitação explícita do usuário.

## Regras

- Reaproveite o estado existente e execute apenas as etapas necessárias; não repita pesquisa ou auditoria válida.
- Delegue pesquisa, segurança, integração e documentação às skills responsáveis, sem duplicar suas instruções operacionais.
- Preserve arquivos locais: faça backup antes de substituir dados e nunca inclua segredos no repositório.
- Peça confirmação antes de uma ação destrutiva, ambígua ou que possa expor dados sensíveis; para o restante, avance e informe as premissas.
- Valide o resultado da integração e comunique claramente qualquer etapa não executada ou bloqueada.
