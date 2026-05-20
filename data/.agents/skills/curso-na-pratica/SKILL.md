---
name: curso-na-pratica
description: Cria cursos 100% práticos onde o aluno aprende fazendo. Cada conceito é introduzido pela ação, não pela teoria. Explica só o que o aluno vai fazer e por que vai fazer. Responde "o que isso faz" e "e se eu não fizer" antes de cada passo. Use quando o usuário pedir curso prático, mão na massa, aprender fazendo, curso experimental, "me põe pra praticar", learning by doing, ou qualquer variação de aprendizado baseado em ação.
---

# Curso na Prática

Cria cursos onde **o aluno pratica antes de entender a teoria**. A explicação vem depois da ação, responde só duas perguntas: **o que isso faz** e **por que importa**.

## Quick Start

1. Receber conteúdo (tema, URL, código, texto) — se URL, buscar na web.
2. Executar as **5 fases** (checklist abaixo) na ordem.
3. Entregar na ordem: resumo → mapa → desafios → projeto final.
4. Usar templates em [templates.md](templates.md).
5. Rodar **F5** antes de enviar.

## Princípios inegociáveis

1. **Ação primeiro, explicação depois** — o aluno executa antes de saber a teoria completa.
2. **Só explica o necessário** — cada conceito é justificado por "o que faz" + "por que importa".
3. **Consequência visível** — todo passo mostra o que acontece se o aluno pular ou errar.
4. **Experimento > Exposição** — o aluno descobre o conceito testando, não lendo sobre ele.
5. **Conteúdo fiel à fonte** — não inventar fatos; marcar lacunas como `⚠️ A VALIDAR`.

## Gatilho e escopo

Ativar quando o usuário pedir:

- Curso prático, mão na massa, aprender fazendo
- "Me põe pra praticar", "quero exercitar", "learning by doing"
- Curso para o aluno que pergunta "o que isso faz?" e "e se eu não fizer?"
- Tema vago com foco em prática ("quero praticar X")

**Não** gerar trilhas múltiplas, taxonomia de Bloom, UDL formal ou teoria extensa. Um caminho: **fazer**.

---

## Fluxo obrigatório (5 fases)

```
Progresso:
- [ ] F1 — Ingestão e mapa da fonte
- [ ] F2 — Mapa de desafios
- [ ] F3 — Produção dos desafios
- [ ] F4 — Projeto final integrador
- [ ] F5 — Auto-verificação final
```

### F1 — Ingestão e mapa da fonte

1. Identificar tipo de entrada e extrair estrutura.
2. Se URL → buscar na web.
3. Produzir **Mapa da Fonte** (curto, focado em ação):

```markdown
## Mapa da Fonte

- **Tipo**: [texto | url | código | misto]
- **Tema central**: uma frase
- **Ações detectadas**: o que dá pra FAZER com esse conteúdo (lista numerada)
- **Conceitos necessários**: mínimo para executar (só o que bloqueia a prática)
- **Lacunas**: ⚠️ A VALIDAR
```

4. Se a fonte for enorme → priorizar por **o que o aluno pode fazer primeiro**, não por ordem do documento.

### F2 — Mapa de desafios

Criar uma **progressão de desafios** (não módulos teóricos):

```
Curso: [Título — benefício direto]
├── Desafio 0: "Quebra-gelo" — algo que funciona em 5 min, sem explicação prévia
├── Desafio 1..N: cada um introduz 1 conceito novo pela ação
└── Desafio Final: projeto que combina tudo
```

**Regras do mapa de desafios:**

- Cada desafio = 1 coisa para fazer + 1 conceito que aparece naturalmente
- Progressão: fácil → médio → difícil, sem saltos
- Ratio: **70% prática | 20% explicação pós-ação | 10% reflexão**
- Entre desafios: 1 parágrafo "o que você acabou de descobrir → o que vem"

### F3 — Produção dos desafios

Para **cada desafio**, usar o template em [templates.md](templates.md).

Regras de redação:

- **Nunca** começar com teoria — começar com "Faça isso:"
- Após o aluno executar, explicar em no máximo 3 frases:
  - **O que aconteceu**: o que o passo fez
  - **Por que importa**: por que isso existe no mundo real
  - **E se pular**: o que quebra ou muda se ignorar esse passo
- Incluir bloco `🧪 Experimente` — variação do passo para o aluno testar e ver o que muda
- Incluir bloco `💥 O que pode dar errado` — 1–2 erros comuns com correção imediata
- Incluir bloco `🤔 Você notou?` — pergunta que faz o aluno observar o resultado da própria ação

Se a fonte for código: o aluno modifica o código primeiro, depois lê por que a mudança funcionou.
Se a fonte for teórica: o aluno aplica o conceito em um micro-cenário, depois lê por que funciona.

### F4 — Projeto final integrador

Um único projeto que combina todos os conceitos dos desafios:

- **Cenário realista** — algo que poderia acontecer no mundo real
- **Sem passo a passo** — só o objetivo e as restrições
- **Pistas opcionais** — hints que o aluno pode consultar se travar (não é tutorial)
- **Critério de pronto** — como saber que terminou
- **Extensão "e se..."** — 2–3 perguntas para quem quer ir além

### F5 — Auto-verificação final

| Critério | ✓ |
| --- | --- |
| O primeiro desafio funciona sem nenhuma leitura prévia? | |
| Cada desafio tem "o que faz" + "por que importa" + "e se pular"? | |
| A teoria nunca aparece antes da ação? | |
| O aluno pratica em ≥70% do tempo? | |
| O projeto final não tem passo a passo (só objetivo)? | |
| Nenhum fato inventado fora da fonte? | |

Se ≥2 itens falharem → revisar antes de entregar.

---

## Formato de entrega

1. **Resumo executivo** (≤ 80 palavras): o que o aluno vai fazer, não o que vai aprender
2. **Mapa da Fonte** (F1)
3. **Mapa de desafios** — lista numerada com título e o que o aluno faz em cada um
4. **Desafios expandidos** — pelo menos Desafio 0 + Desafio 1 completos; demais seguem template resumido se o usuário pedir versão compacta
5. **Projeto final** (F4)

---

## Modos de operação

| Pedido do usuário | Ação |
| --- | --- |
| "Curso prático" / sem qualificador | Fluxo 5 fases, tudo expandido |
| "Só os desafios / outline" | F1–F2 + lista de desafios, sem expandir |
| "Desafio único sobre X" | F1 resumido + 1 desafio no template completo |
| "Mais difícil / mais fácil" | Ajustar complexidade do desafio, não adicionar teoria |
| "A partir desta URL" | Fetch → Mapa da Fonte → fluxo normal |

---

## Pesquisa externa

- **Pode e deve** pesquisar para: validar comportamentos, exemplos reais, boas práticas.
- Citar fontes quando adicionar info fora da entrada: `📎 Fonte: [título](url)`.

---

## Idioma e tom

- Idioma = idioma do pedido (padrão: português brasileiro).
- Tom: direto, conversacional, como um colega experiente mostrando o caminho.
- Sem academicismo. Sem "ao final desta lição o aluno será capaz de".
- Usar "você" e imperativo: "faça", "rode", "mude", "observe".

---

## Recursos

- Templates de desafio e projeto final: [templates.md](templates.md)
- Exemplos e anti-padrões: [examples.md](examples.md)
