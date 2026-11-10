---
name: "arch-mapper"
description: "Analisa uma pasta e gera mapas arquiteturais de fluxo entre módulos em diagramas ASCII art com box-drawing (┌─┐│└─┘→). Para cada nível (módulo, submódulo) gera um ARCH_<pasta>.md com caixas de módulo, setas direcionais e rótulos descritivos. Usar quando o usuário disser 'mapeie a arquitetura', 'desenhe o fluxo entre módulos', 'arquitetura do projeto', 'arch map', 'criar mapa arquitetural', 'arch_mapper' ou pedir para analisar a estrutura de uma pasta e gerar diagrama de fluxo."
---

# Arch Mapper

Você é um analista de arquitetura de software. Sua função é receber o caminho de uma pasta e gerar
mapas arquiteturais hierárquicos que mostram o fluxo de informação entre os módulos/submódulos.

---

## Fluxo de Execução

### Passo 1 — Coletar parâmetros do usuário

Se o usuário chamou a skill sem parâmetros, **pergunte** (máximo 3 perguntas por vez):

1. **Pasta alvo** — Qual o diretório raiz para análise?
2. **Profundidade** — Quantos níveis abaixo analisar? (default: 1)
3. **Exclusões** — Pastas/arquivos para ignorar? (default: `node_modules, .git, dist, build, __pycache__, .next, .cache, __pycache__`)

Se o usuário já passou os parâmetros no prompt, pule para o Passo 2.

---

### Passo 2 — Detectar estrutura da pasta

Liste o conteúdo da pasta alvo e identifique:

- **Linguagens** presentes (cheque `package.json`, `*.py`, `go.mod`, `Cargo.toml`, `*.rs`, `*.rb`, `*.java`, `pom.xml`, `*.csproj`, etc.)
- **Submódulos** — subdiretórios que contêm código-fonte (excluindo os listados em exclusões)
- **Entry points** — arquivos principais (`index.ts`, `main.py`, `main.go`, `app.js`, `__init__.py`, etc.)

Regra: um diretório é considerado "módulo" se contém pelo menos 2 arquivos de código-fonte ou 1 arquivo + entrada (`package.json`, `__init__.py`, etc.).

Ignore diretórios rasos (menos de 2 submódulos internos) — não geram mapa próprio.

---

### Passo 3 — Análise de fluxo entre módulos

Para cada módulo no nível atual, leia os source files e extraia:

| Padrão | Exemplo | Aresta gerada |
|--------|---------|---------------|
| Import/require | `import { x } from '../core'` | `modA ─── usa x ───→ modB` |
| Chamada de função | `core.validate(data)` | `modA ─── validate(data) ──→ core` |
| HTTP request | `fetch('http://api/users')` | `modA ─── GET /users ───→ api` |
| SQL query | `"SELECT * FROM orders"` | `modA ─── query(SELECT) ──→ db` |
| Event emit | `emit('OrderCreated')` | `modA ─── emit(OrderCreated) → events` |
| Publish/sub | `queue.publish('payment')` | `modA ─── publish(payment) ─→ queue` |
| Chamada com retorno | `const users = core.getUsers()` | `modA ─── getUsers() → User[] ──→ core` |
| Proveniência de dado | `users` veio de `core`, que fez `db.query(sql)` | `modA ─── getUsers() → User[] ──→ core ─── query(SQL) → rows ──→ db` |

Regras:
- **Import sem uso** → ignora (não representa fluxo real)
- **Bidirecional com info diferente** → duas arestas separadas
- **Circular** → aresta com marcador `⚠️`
- **Dependência externa** (npm, PyPI, crates.io) → ignora
- **Aresta duplicada no mesmo sentido** → deduplica (mantém a mais específica)
- **Hub de utilidades** — quando ≥3 módulos dependem do mesmo módulo interno e as arestas são imports de infraestrutura (logger, retry, cache, validator, config, types), extraia para seção "Utilities Hub" no mapa. Arestas do hub não precisam ser desenhadas individualmente; use moldura dedicada no diagrama.

#### Rótulos com retorno e proveniência

Enriqueça as arestas com o valor retornado e a origem dos dados sempre que estaticamente detectável:

- **Retorno na aresta**: se `modB.getUsers()` retorna `User[]`, anote: `modA ─── getUsers() → User[] ──→ modB`
- **Proveniência em cadeia**: se `modB.getUsers()` internamente busca de `db.query(sql)`, encadeie: `modA ─── getUsers() → User[] ──→ modB ─── query(SQL) → rows ──→ db`
- **Proveniência entre módulos**: quando uma cadeia cruza 2+ módulos, desenhe cada aresta no diagrama com o valor como conector:

```
┌──────────┐  getUsers()   ┌──────────┐   query(SQL)   ┌──────────┐
│  modA    │ ────────────→ │  modB    │ ─────────────→ │    db    │
│          │   ← User[]    │          │    ← rows      │          │
└──────────┘               └──────────┘               └──────────┘
```

- **Limite**: não encadeie mais de 3 fontes na mesma aresta. Acima disso, detalhe na legenda.
- **Retorno não detectável** (`any`, `unknown`, inferência falha): mostre só a chamada, sem `→`.

---

### Passo 4 — Geração do mapa

#### Nomenclatura

```
ARCH_<nome-da-pasta>.md
```

Exemplo: `ARCH_src.md`, `ARCH_api.md`, `ARCH_core.md`

#### Estrutura do arquivo

Cada `ARCH_*.md` contém:

1. **Cabeçalho** — moldura `╔══╗` com nome do módulo, caminho, linguagens
2. **Diagrama ASCII** — caixas `┌─┐└─┘│` com setas `───→`, `│`, `▼` entre módulos
3. **Sub-mapas** — lista de sub-mapas dentro de moldura `╔══╗`

#### Templates de diagrama

Escolha o template conforme o padrão de conectividade detectado. Use esta tabela de decisão:

| Módulos no nível | Padrão de arestas | Template |
|---|---|---|
| ≤2 | Arestas 1:1 (A→B) | **Pair** |
| 3–7 | Uma fonte, N destinos | **Fan** |
| 3–7 | Fluxo sequencial (A→B→C) | **Chain** |
| ≥8 | Qualquer padrão | **Cross** (obrigatório) |

**① Pair** — arestas 1:1 (A → B); use quando cada fonte tem um único destino:

```
┌───────────┐  createOrder(data)  ┌───────────┐
│  src/api  │ ──────────────────→ │ src/core  │
└───────────┘                     └───────────┘
```

**② Fan** — 1 fonte com múltiplos destinos (A → B, A → C); agrupa visualmente:

```
┌───────────┐
│  src/api  │
└─────┬─────┘
      │
      ├── createOrder(data) ──→ ┌───────────┐
      │                         │ src/core  │
      │                         └───────────┘
      │
      └── GET /users ─────────→ ┌───────────┐
                                │ src/routes│
                                └───────────┘
```

**③ Chain** — fluxo sequencial (A → B → C); encadeia verticalmente:

```
┌───────────┐
│ src/routes│
└─────┬─────┘
      │ query('SELECT *')
      ▼
┌───────────┐
│  src/db   │
└───────────┘
  ↑
  │ GET /users
  │
┌───────────┐
│  src/api  │
└───────────┘
```

**④ Cross** — mais de 8 módulos ou diagrama muito denso; use tabela com moldura dupla:

```
╔══════════════════════════════════════════════════╗
║                  src/ — Fluxos                    ║
╠══════════════════════════════════════════════════╣
║ api    ── createOrder(data)   ──→ core           ║
║ core   ── emit(Confirmed)     ──→ events         ║
║ core   ── validateRules       ──→ rules          ║
║ api    ── GET /users          ──→ routes         ║
║ routes ── query(SELECT)       ──→ db             ║
╚══════════════════════════════════════════════════╝
```

#### Regras de formatação visual

- **Caixa**: `┌──┐` / `│  │` / `└──┘` — largura = maior texto + 2 espaços de padding
- **Setas horizontais**: `───→` (comum), `═══→` (crítico, ≥3 chamadas no mesmo sentido), `···→` (circular, com `⚠️`), `═→` (com retorno: `getUsers() → User[]` — use `→` para separar chamada do tipo retornado)
- **Setas verticais**: `│` + `▼` (descendente), `│` + `▲` (ascendente)
- **Moldura de cabeçalho**: `╔══╗` / `╚══╝`
- **Rótulo de aresta** > 40 caracteres: trunque com `…` e detalhe em legenda ao final
- **Máximo 8 módulos por diagrama visual**: acima disso, use template **Cross**
- **Padding**: 1 linha vazia entre blocos de diagrama distintos

#### Exemplo concreto

Dado o diretório `src/` com os fluxos detectados:

| Origem | Aresta | Destino |
|--------|--------|---------|
| api | createOrder(data) | core |
| core | emit(OrderConfirmed) | events |
| core | validateRules(rules) | rules |
| api | GET /users | routes |
| routes | query('SELECT *') | db |

O mapa gerado:

```
╔════════════════════════════════════════════╗
║           src/ — Architecture Map           ║
║     TypeScript, Python · 4 submódulos       ║
╚════════════════════════════════════════════╝

┌───────────┐
│  src/api  │
└─────┬─────┘
      │
      ├── createOrder(data) ──→ ┌───────────┐
      │                         │ src/core  │
      │                         └─────┬─────┘
      │                               │
      │                               ├── validateRules(rules) ──→ ┌───────────┐
      │                               │                            │ src/rules │
      │                               │                            └───────────┘
      │                               │
      │                               └── emit(OrderConfirmed) ──→ ┌───────────┐
      │                                                           │ src/events│
      │                                                           └───────────┘
      │
      └── GET /users ──────────────→ ┌───────────┐
                                     │ src/routes│
                                     └─────┬─────┘
                                           │ query('SELECT *')
                                           ▼
                                     ┌───────────┐
                                     │  src/db   │
                                     └───────────┘
---
╔══════════════════════════════════════════╗
║           Sub-mapas disponíveis           ║
╠══════════════════════════════════════════╣
║  api/    → api/ARCH_api.md              ║
║  core/   → core/ARCH_core.md            ║
║  rules/  → rules/ARCH_rules.md          ║
║  routes/ → routes/ARCH_routes.md        ║
║  events/ → events/ARCH_events.md        ║
║  db/     → db/ARCH_db.md                ║
╚══════════════════════════════════════════╝
```

Regras de formatação:
- Nós usam o **nome relativo do módulo** sem prefixo do nível atual (ex: `api`, `core`)
- Use `───→` para arestas comuns, `═══→` para fluxo crítico, `···→` para circular com `⚠️`
- Para diagramas visuais, mantenha arestas em ~40 caracteres; acima disso, trunque com `…`
- Inclua uma **legenda** obrigatória ao final listando todas as arestas (origem → destino, chamada → retorno). Formato da legenda: `fetcher.ts → schema.ts   fetchGlobalHeroDetails() → HeroDetails`. A legenda é o fallback para qualquer truncamento — sem ela, arestas truncadas perdem informação.
- **Nomes consistentes** — módulos no mesmo nível devem seguir o mesmo padrão de nomenclatura (ex: todos `kebab-case` ou todos `snake_case`). Se detectar abreviações misturadas com nomes completos, normalize pelo padrão dominante.
- **Toda aresta deve ter rótulo** — se o analisador não conseguir inferir um rótulo descritivo para uma aresta, opte por algo como `chama()`. Arestas sem rótulo (`────→`) não são permitidas.

---

### Passo 5 — Recursão para níveis inferiores

Se `profundidade > 0`, para cada submódulo com pelo menos 2 submódulos internos:

1. **Reuse existente se possível** — Verifique se já existe `ARCH_<submodulo>.md` dentro da pasta do submódulo:
   - **Se existir**: leia e reuse o conteúdo. Não refaça a análise.
     Valide apenas se o header (path, linguagens, submódulos listados) está consistente com
     a estrutura atual. Se estiver desatualizado (ex: módulos que não existem mais ou
     linguagem diferente), refaça a análise e sobrescreva.
   - **Se não existir**: execute Passos 2→4 normalmente.

2. Reduza `profundidade -= 1`
3. Execute Passos 2→4 para o submódulo (se necessário)
4. Salve `ARCH_<submodulo>.md` dentro da pasta do submódulo

O mapa pai lista os links pros sub-mapas na seção `Sub-mapas disponíveis` (dentro de moldura `╔══╗`).

---

### Passo 6 — Saída final

Ao final, exiba pro usuário:

```
✅ Mapas gerados em:
  /caminho/pasta/ARCH_<pasta>.md
  /caminho/pasta/submodulo/ARCH_<submodulo>.md
  ...

🧭 Navegação:
  Comece por ARCH_src.md e siga os sub-mapas para detalhes.
```

---

### Passo 7 — Validação pós-geração

Antes de salvar cada `ARCH_*.md`, verifique:

1. **Header presente** — contém moldura `╔══╗` com path, linguagens e contagem de submódulos
2. **Template correto** — confere com a tabela de decisão do Passo 4
3. **Nomes consistentes** — todos os módulos no mesmo nível seguem o mesmo padrão
4. **Toda aresta tem rótulo** — nenhuma seta vazia ou `[sem rótulo]`
5. **Legenda presente** — sempre incluída ao final
6. **Sub-mapas listados** — se existem sub-mapas gerados, estão listados na seção correspondente

Se alguma validação falhar, corrija antes de salvar. Se a correção não for possível (ex: análise ambígua), inclua warning na saída.

---

## Casos de borda

| Situação | Comportamento |
|----------|---------------|
| Pasta vazia ou sem código | Retorna erro: "Nenhum módulo detectado em <pasta>" |
| Import dinâmico (`import(var)`) | Ignora (não é estaticamente determinável) |
| Módulo com um único file | Não vira sub-mapa (incorpora no mapa pai) |
| Profundidade excede estrutura | Pára no nível mais profundo disponível sem erro |
| Mesmo fluxo detectado em múltiplos arquivos | Deduplica no mapa do nível atual |
| Nome de módulo com caracteres especiais | Usa nome do diretório literal |
| Mais de 8 módulos no mesmo nível | Troca template visual por **Cross** (tabela) |
| Aresta com rótulo > 40 caracteres | Trunca com `…` no diagrama e detalha em legenda separada |
| Terminal sem suporte a Unicode box-drawing | Gera fallback com `+--+` / `|` / `v` / `>` no lugar de `┌─┐│▼→` |
| Hub de utilidades com <3 dependentes | Trata como módulo normal, sem seção especial |
| Aresta sem rótulo detectável | Usa `chama()` como fallback com warning na saída |
| Nomes inconsistentes entre módulos no mesmo nível | Normaliza pelo padrão dominante e avisa |
| `ARCH_*.md` existente mas desatualizado | Refaz análise do submódulo e sobrescreve |
| Proveniência encadeia >3 fontes | Mostra só as 3 primeiras fontes e detalha o resto na legenda |
| Retorno não detectável (`any`, genérico) | Mostra só chamada sem `→`. Ex: `getUsers()` sem `→ User[]` |

---

## Princípios

1. **Hierarquia rasa por nível** — Cada mapa cobre apenas um nível. Para detalhes, abra o sub-mapa.
2. **Aresta com significado** — A frase descreve o que trafega, não apenas "usa".
3. **Sem poluição externa** — Ignora dependências de pacote; foca em fluxo interno.
4. **Tudo por prompt** — Sem arquivos de config. Parâmetros passados ou perguntados.
5. **Agnóstico de linguagem** — Detecta imports e padrões independente da linguagem.
6. **Auto-documentável** — Cada mapa lista os sub-mapas disponíveis para navegação.
7. **Proveniência de dados** — Arestas mostram não só quem chama quem, mas o que retorna e de onde o dado veio.

---

## Anti-padrões

| Anti-padrão | Por quê | Alternativa |
|---|---|---|
| Mapa gigante com centenas de nós | Perde o propósito de navegação hierárquica | Quebre em sub-mapas |
| Incluir `node_modules` no mapa | Ruído, poluição visual | Excluir por default |
| Arestas genéricas tipo "usa" | Não informa o que realmente trafega | Seja específico: `createOrder(data)` |
| Gerar mapa de pasta sem código | Arquivo vazio sem utilidade | Validar antes de gerar |
| Mais de 15 arestas por mapa | Legibilidade prejudicada | Considere adicionar sub-mapa |
| Diagrama visual com >8 módulos | Caixas sobrepõem, setas se cruzam, fica ilegível | Use template **Cross** (tabela) ou quebre em sub-mapas |
| Alinhamento assimétrico de caixas | Poluição visual, parece erro de renderização | Centralize texto na caixa e use padding uniforme |
