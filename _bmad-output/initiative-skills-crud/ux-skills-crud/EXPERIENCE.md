---
name: Skills GUI
status: final
sources:
  - ../initiative-skills-crud.md
updated: 2026-11-10
---

# Skills GUI — Experience Spine (CRUD de Skills)

> Especificação de interação, arquitetura da informação, comportamento, estados e jornadas para o CRUD de Agent Skills no aplicativo desktop Skills GUI (Tauri 2).

## Foundation

Aplicativo Desktop em **Tauri 2** (Linux/X11/Wayland e Windows nativo). Frontend vanilla TypeScript com renderização reativa sem frameworks pesados, estilizado com CSS customizado seguindo o tema Catppuccin Mocha. O backend Rust expõe comandos seguros via IPC com controle de permissão e limites de diretório canônico. O arquivo visual de referência é o `DESIGN.md`.

Princípio fundamental de experiência: **Autonomia com Guardrails**. O usuário deve conseguir criar e editar habilidades para seus agentes com velocidade instantânea, mas operações de exclusão física exigem fricção positiva para proteger arquivos de código do repositório.

## Information Architecture

| Superfície | Como é acessada | Papel no CRUD |
|---|---|---|
| **Toolbar Principal** | Topo da área principal | Acesso primário ao botão `+ Nova Skill` (`Alt+N` / `Ctrl+N`) e busca. |
| **Modal de Criação** | Clique em `+ Nova Skill` | Formulário focado para registrar nova skill no disco e catálogo. |
| **Drawer de Detalhes** | Clique em qualquer card da grid | Inspeção e edição de metadados, visualizador/editor de `SKILL.md` e gatilho de exclusão. |
| **Aba Editor de SKILL.md** | Toggle no topo da seção de conteúdo do Drawer | Edição in-app do Markdown (`SKILL.md`) com salvamento rápido (`Ctrl+S`). |
| **Modal de Exclusão (Zona de Perigo)** | Clique no botão `Excluir Skill` no Drawer | Diálogo de barreira consciente para exclusão definitiva do disco e limpeza do catálogo. |
| **Toast de Notificação** | Canto inferior direito | Confirmação não-bloqueante de operações + atalho contextual para aplicar bridge. |

## Voice and Tone

Microcopy direto, técnico e focado na precisão de desenvolvedores.

| Faça | Evite |
|---|---|
| "Skill 'docker-expert' criada com sucesso. [🔗 Aplicar bridge]" | "Parabéns! Sua nova habilidade foi criada com sucesso! 🚀" |
| "Nome já em uso no acervo de skills." | "Opa, esse nome não pode." |
| "Esta ação remove permanentemente a pasta 'data/.agents/skills/foo' do disco." | "Você tem certeza que quer excluir isso?" |
| "Para confirmar a exclusão, digite 'foo' abaixo:" | "Clique em OK para deletar tudo." |
| "Instruções salvas no arquivo SKILL.md." | "Alterações salvas com sucesso!" |

## Component Patterns

### 1. Botão e Formulário de Criação (`+ Nova Skill`)
- **Comportamento do Campo Slug**:
  - Converte automaticamente maiúsculas e espaços em hífen enquanto o usuário digita (`Minha Nova Skill` → `minha-nova-skill`).
  - Validação em tempo real: compara com a lista em memória de skills existentes (`disk_names`). Se houver colisão ou caractere inválido, exibe feedback de erro e desabilita o botão de submissão.
- **Seleção de Categoria e Ferramentas**:
  - Categoria inicia com a categoria atualmente filtrada na sidebar (ou "Sem categoria" se em 'Todas').
  - Ferramentas de IA (bridge) iniciam todas marcadas por padrão (pois no acervo flat as skills geralmente estão disponíveis para todos os agentes configurados).
- **Template de SKILL.md**:
  - Oferece opção de preenchimento automático:
    - *Padrão*: Gera frontmatter YAML com `name` e `description` + esqueleto de seções `## Overview` e `## Instructions`.
    - *Vazio*: Apenas frontmatter YAML mínimo.

### 2. Editor In-App de `SKILL.md` (no Drawer)
- **Alternador Visualizar / Editar**:
  - Modo padrão ao abrir o drawer: `Visualizar` (leitura formatada em bloco de código monoespaçado).
  - Ao alternar para `Editar`: o bloco se transforma em um `<textarea>` com altura ajustada, desabilitando scroll acidental da página.
- **Atalhos e Salvamento**:
  - `Ctrl+S` (ou `Cmd+S`) com foco no textarea salva imediatamente via comando Tauri `save_skill_content`.
  - Indicador de estado modificado: exibe um pequeno ponto ou indicador `(modificado)` enquanto houver alterações não salvas.
  - Se o usuário tentar fechar o drawer com alterações pendentes, um aviso de confirmação rápida previne perda de digitação.

### 3. Modal de Exclusão Destrutiva (Zona de Perigo)
- **Fricção Positiva**:
  - O botão primário "Excluir Definitivamente" permanece estritamente `disabled` até que o valor digitado no input seja idêntico ao nome da skill.
  - Pressionar `Enter` no input de confirmação só dispara a exclusão se o nome for válido.
- **Teclado**:
  - `Esc` fecha o modal imediatamente sem executar nenhuma ação.

## State Patterns

| Estado | Onde ocorre | Comportamento na Interface |
|---|---|---|
| **Criação em andamento** | Modal de Criação | Botão "Criar" exibe spinner e desabilita inputs para evitar duplo clique. |
| **Slug Inválido / Colisão** | Modal de Criação | Borda do input fica em `{colors.danger}`, texto de erro aparece abaixo do campo. |
| **Salvamento do SKILL.md** | Drawer de Detalhes | Botão "Salvar" exibe feedback "Salvando...", seguido de toast `{colors.success}`. |
| **Exclusão confirmada** | Modal de Exclusão | Fecha o modal e o drawer simultaneamente; remove o card da grid com animação fade-out; exibe toast: `Skill excluída com sucesso. [🔗 Sincronizar Bridge]`. |
| **Erro de I/O no Rust** | Qualquer operação | Exibe toast persistente em `{colors.danger}` com a mensagem do erro vinda do sistema de arquivos. |

## Interaction Primitives

- **Teclas de Atalho Globais**:
  - `Alt+N` ou `Ctrl+N`: Abre o modal de criação de skill a partir de qualquer ponto da tela.
  - `Esc`: Fecha modais abertos ou fecha o drawer ativo.
  - `Ctrl+S` (no editor do drawer): Dispara o salvamento do `SKILL.md`.
- **Foco e Acessibilidade**:
  - Ao abrir o modal de criação, o foco vai automaticamente para o campo "Nome da Skill".
  - Ao abrir o modal de exclusão, o foco vai diretamente para o campo de confirmação digitada.

## Accessibility Floor

- **Contraste de Cores**: Todo texto informativo possui contraste mínimo de 4.5:1 contra os fundos Catppuccin Mocha.
- **Navegação por Teclado**: Todo o fluxo de criação, edição e exclusão pode ser executado integralmente via teclado (Tab, Shift+Tab, Enter, Esc, Ctrl+S).
- **Semântica**: Inputs utilizam labels associados explicitamente via atributos `for`/`id`, e modais utilizam `role="dialog"` e `aria-modal="true"`.

## Key Flows (Jornadas do Usuário)

### Jornada 1: Criação Instantânea de uma Nova Skill
- **Protagonista**: Max, configurando um novo agente especialista em Docker.
1. Max está no *Skills GUI* navegando pela categoria "DevOps".
2. Ele pressiona `Alt+N` (ou clica no botão `+ Nova Skill` na toolbar).
3. O modal de criação surge suavemente. O foco está no campo de nome.
4. Max digita `docker-specialist`. O sistema valida em tempo real: badge verde indica que o nome está livre.
5. Max preenche a descrição: *"Especialista em Dockerfiles multi-stage e otimização de imagens OCI"*.
6. A categoria já vem pré-selecionada como "DevOps" (contexto da visualização anterior). As ferramentas vêm todas marcadas.
7. Max clica em "Criar Skill" (`Enter`).
8. **Clímax**: Em frações de segundo, o backend Rust cria o diretório `data/.agents/skills/docker-specialist/`, gera o `SKILL.md` padronizado e injeta a entrada no `skills-catalog.json`.
9. O modal se fecha, o novo card aparece destacado na grid e o drawer lateral abre automaticamente já pronto para edição, com um toast no rodapé: *"Skill 'docker-specialist' criada. [🔗 Aplicar bridge]"*.

### Jornada 2: Edição das Instruções de uma Skill Existente
- **Protagonista**: Max, refinando as diretrizes de uma skill existente (`git-commit`).
1. Max pesquisa `git-commit` na barra de busca e clica no card.
2. O drawer abre exibindo os metadados. Abaixo, na seção de instruções, ele clica na aba `[✏️ Editar]`.
3. O preview estático se transforma em uma área de edição de código monoespaçada com as diretrizes do `SKILL.md`.
4. Max adiciona uma nova regra sobre convenção de commits atômicos.
5. Ele pressiona `Ctrl+S`.
6. O botão exibe confirmação visual imediata e um toast confirma que o arquivo foi gravado no disco sem necessidade de abrir um editor externo.

### Jornada 3: Descarte e Exclusão Segura
- **Protagonista**: Max, limpando uma skill experimental que não é mais necessária (`test-temp-agent`).
1. Max abre a skill `test-temp-agent` no drawer.
2. Rola até o final e encontra a seção delimitada com borda sutil em vermelho: `Zona de Perigo`.
3. Ele clica em `Excluir Skill`.
4. Um modal com borda de perigo surge. O texto explica com clareza: a pasta em `data/.agents/skills/test-temp-agent` será apagada, os metadados no catálogo serão removidos e os symlinks do bridge serão desvinculados.
5. O botão "Excluir Definitivamente" está desabilitado.
6. Max digita `test-temp-agent`. Ao completar o último caractere, o botão fica vermelho e ativo.
7. Max pressiona `Enter`.
8. **Clímax**: O backend Rust remove a pasta do disco, higieniza o `skills-catalog.json` e fecha as janelas. O card desaparece suavemente da tela e um toast oferece o botão com 1 clique para atualizar os symlinks das ferramentas via bridge. Zero arquivos órfãos, zero risco de exclusão por engano.
