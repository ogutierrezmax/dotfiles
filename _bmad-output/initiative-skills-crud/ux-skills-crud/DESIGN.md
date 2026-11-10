---
name: Skills GUI
description: Gerenciador desktop (Tauri 2) do acervo de agent skills dos dotfiles. Catppuccin Mocha dark theme.
colors:
  bg-primary: '#181825'
  bg-secondary: '#1e1e2e'
  bg-tertiary: '#313244'
  bg-hover: '#45475a'
  border: '#45475a'
  text-main: '#cdd6f4'
  text-secondary: '#a6adc8'
  text-muted: '#6c7086'
  accent: '#89b4fa'
  accent-hover: '#b4befe'
  success: '#a6e3a1'
  warning: '#f9e2af'
  danger: '#f38ba8'
  danger-hover: '#eba0ac'
  info: '#89dceb'
  purple: '#cba6f7'
typography:
  font-sans:
    fontFamily: "system-ui, -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Ubuntu, sans-serif"
    fontSize: 14px
    lineHeight: '1.5'
  font-mono:
    fontFamily: "'JetBrains Mono', 'Fira Code', 'MesloLGS NF', monospace"
    fontSize: 13px
    lineHeight: '1.6'
  heading-lg:
    fontFamily: "system-ui, -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Ubuntu, sans-serif"
    fontSize: 18px
    fontWeight: '600'
    lineHeight: '1.3'
  heading-md:
    fontFamily: "system-ui, -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Ubuntu, sans-serif"
    fontSize: 15px
    fontWeight: '600'
    lineHeight: '1.3'
  label:
    fontFamily: "system-ui, -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Ubuntu, sans-serif"
    fontSize: 12px
    fontWeight: '500'
    lineHeight: '1.4'
rounded:
  sm: 4px
  md: 8px
  lg: 12px
  full: 9999px
spacing:
  xs: 4px
  sm: 8px
  md: 12px
  lg: 16px
  xl: 24px
components:
  btn-primary:
    background: '{colors.accent}'
    foreground: '{colors.bg-primary}'
    radius: '{rounded.md}'
    fontWeight: '600'
  btn-danger:
    background: 'transparent'
    foreground: '{colors.danger}'
    border: '1px solid {colors.danger}'
    radius: '{rounded.md}'
    hoverBackground: 'rgba(243, 139, 168, 0.15)'
  modal-danger:
    background: '{colors.bg-secondary}'
    border: '1px solid {colors.danger}'
    radius: '{rounded.lg}'
  editor-textarea:
    background: '{colors.bg-primary}'
    foreground: '{colors.text-main}'
    fontFamily: '{typography.font-mono.fontFamily}'
    fontSize: '{typography.font-mono.fontSize}'
    border: '1px solid {colors.border}'
    radius: '{rounded.md}'
  slug-input:
    background: '{colors.bg-primary}'
    foreground: '{colors.text-main}'
    fontFamily: '{typography.font-mono.fontFamily}'
    border: '1px solid {colors.border}'
    radius: '{rounded.md}'
---

# Skills GUI — DESIGN.md (Visual Identity)

## Brand & Style

O **Skills GUI** é a central de comando do desenvolvedor para o ecossistema de habilidades dos seus agentes de IA. A estética segue a paleta **Catppuccin Mocha**: um tema escuro e acolhedor com alto contraste para leitura e baixa fadiga visual durante longas sessões de código.

A postura visual transmite **controle cirúrgico, robustez de terminal e clareza desktop**. Não há decorações gratuitas, gradientes excessivos ou sombras pesadas: a interface se apoia em bordas finas (`1px solid {colors.border}`), tipografia monoespaçada onde o dado é código e cores funcionais estritas.

## Colors

- `{colors.bg-primary}` (`#181825`): Fundo principal da aplicação e de áreas de edição (textareas, inputs de código). Dá profundidade máxima.
- `{colors.bg-secondary}` (`#1e1e2e`): Fundo do header, sidebar, cards e modais. Camada intermediária de elevação.
- `{colors.bg-tertiary}` (`#313244`): Elementos interativos secundários, badges e cabeçalhos de tabela.
- `{colors.accent}` (`#89b4fa`): O azul Mocha como cor primária de destaque. Utilizado para botões principais (`+ Nova Skill`, `Aplicar bridge`), foco de inputs e tags selecionadas.
- `{colors.danger}` (`#f38ba8`): Vermelho suave para destruição de dados. Usado exclusivamente na zona de perigo de exclusão de skills.
- `{colors.success}` (`#a6e3a1`): Confirmações, status de bridge sincronizado e validações positivas em tempo real.
- `{colors.warning}` (`#f9e2af`): Alertas de drifts ou conflitos não-fatais.
- `{colors.text-main}` (`#cdd6f4`) & `{colors.text-secondary}` (`#a6adc8`): Hierarquia de legibilidade textual.

## Typography

- **Interface geral**: `{typography.font-sans.fontFamily}` para menus, labels, botões e descrições.
- **Identificadores e código**: `{typography.font-mono.fontFamily}` (`JetBrains Mono`, `Fira Code` ou mono de sistema) obrigatório para:
  - Slugs de skill (`my-agent-skill`).
  - Caminhos de arquivo (`data/.agents/skills/...`).
  - Corpo das instruções no editor de `SKILL.md`.
  - Tags de ferramentas (`claude`, `opencode`, `cursor`).

## Layout & Spacing

- **Escala de Espaçamento**: Base 4px (`{spacing.xs}`: 4px, `{spacing.sm}`: 8px, `{spacing.md}`: 12px, `{spacing.lg}`: 16px, `{spacing.xl}`: 24px).
- **Densidade**: Alta densidade de informação, condizente com ferramentas de desenvolvedor.
- **Modais**: Centralizados com backdrop escurecido (`rgba(0, 0, 0, 0.65)`), largura máxima de `540px` para criação e `480px` para confirmação de exclusão.
- **Drawer**: Largura fixa de `480px` na borda direita, scroll independente, transição suave de entrada (`transform: translateX`).

## Elevation & Depth

- A profundidade é comunicada por **tons de cor** e **bordas**, não por sombras difusas:
  - Nível 0 (Fundo): `{colors.bg-primary}`
  - Nível 1 (Superfície): `{colors.bg-secondary}` com borda `{colors.border}`
  - Nível 2 (Popovers e Modais): `{colors.bg-secondary}` com sombra discreta (`0 8px 24px rgba(0, 0, 0, 0.5)`) e borda destacada.

## Shapes

- Botões, inputs e badges usam cantos ligeiramente arredondados (`{rounded.md}`: 8px).
- Tags e pílulas de status usam formato cápsula (`{rounded.full}`).
- Janelas modais e cards da grid usam curvatura confortável (`{rounded.lg}`: 12px).

## Components

### 1. Botão "+ Nova Skill"
- Posição: Toolbar principal ao lado da barra de busca.
- Estilo: `{components.btn-primary}` — Fundo `{colors.accent}`, texto contrastante, ícone `+` seguido de texto legível.

### 2. Modal de Criação de Skill
- Card de diálogo modal com cabeçalho limpo: `🧩 Criar Nova Skill`.
- Campos organizados verticalmente com `{spacing.md}` de intervalo.
- Input de slug com prefixo ou dica de convenção (`kebab-case`).
- Indicador visual em tempo real: check verde (`{colors.success}`) para nome disponível e válido; aviso vermelho (`{colors.danger}`) para nome já em uso no acervo.

### 3. Editor de Conteúdo (SKILL.md) no Drawer
- Alternador de abas no topo da seção de conteúdo: `[👁️ Visualizar]` e `[✏️ Editar]`.
- Área de edição: `{components.editor-textarea}` com scroll suave, números de linha (ou espaçamento confortável), redimensionamento vertical e contador de linhas.
- Barra de ação do editor: Atalho visível (`Ctrl+S para salvar`), botão `💾 Salvar SKILL.md` e botão `↗ Abrir no Editor`.

### 4. Modal de Confirmação Destrutiva (Exclusão)
- Estilizado como `{components.modal-danger}`.
- Ícone de alerta `⚠️` e badge `Zona de Perigo`.
- Input de confirmação digitada: campo monoespaçado esperando a repetição exata do slug da skill.
- Botão de confirmação de exclusão `{components.btn-danger}` ativado apenas quando o texto digitado bate com o slug.

## Do's and Don'ts

| Prática | Status | Justificativa |
|---|---|---|
| Usar fonte monoespaçada para slugs de skills e edição de SKILL.md | **DO** | Garante clareza sintática e precisão em caracteres especiais. |
| Fornecer feedback imediato sobre a colisão de nome durante a digitação | **DO** | Evita erro tardio de I/O após o envio do formulário. |
| Exigir confirmação digitada para exclusão definitiva | **DO** | Fricção deliberada para proteger arquivos reais do repositório. |
| Deletar arquivos sem aviso sobre impacto nos symlinks das ferramentas | **DON'T** | Pode quebrar ambientes de IA ativos do usuário silenciosamente. |
| Usar modais sobrepostos (modal sobre modal) | **DON'T** | Manter no máximo um modal ativo por vez para preservar clareza de contexto. |
