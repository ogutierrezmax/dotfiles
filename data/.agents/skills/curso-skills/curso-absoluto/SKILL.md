---
name: "curso-absoluto"
description: "Transforma qualquer conteúdo bruto (texto, URL, código, transcrição, PDF, planilha, áudio descrito) em curso completo e acessível para qualquer público, com trilhas Essencial/Padrão/Mestre, UDL e design reverso. Use quando o usuário pedir criar curso, trilha de aprendizado, módulo didático, e-learning, apostila estruturada, material de ensino, curso absoluto, curso para qualquer público, ou transformar conteúdo em formação."
---

# Curso Absoluto

Transforma **qualquer entrada** em um **curso completo**, adaptável a **qualquer público**, sem depender de stack, domínio ou formato de origem.

## Quick Start

1. Receber conteúdo (texto, URL, código, tema) — se URL, buscar na web; não exigir arquivos locais.
2. Executar as **7 fases** (checklist abaixo) na ordem.
3. Entregar pacote na ordem de **Formato de entrega** (resumo → mapa → trilhas → currículo → aulas → avaliações).
4. Usar templates em [templates.md](templates.md); exemplos em [examples.md](examples.md).
5. Rodar **F7** antes de enviar; corrigir se ≥2 critérios falharem.

## Princípios inegociáveis

1. **Design reverso primeiro** — resultados de aprendizagem → avaliações → atividades → conteúdo.
2. **UDL (Universal Design for Learning)** — sempre oferecer múltiplos caminhos de engajamento, representação e expressão.
3. **Progressão em espiral** — conceitos retornam com mais profundidade; nunca saltos cognitivos grandes.
4. **Acessibilidade por padrão** — linguagem clara, estrutura previsível, alternativas sensoriais, baixa carga cognitiva.
5. **Conteúdo fiel à fonte** — não inventar fatos; marcar lacunas como `⚠️ A VALIDAR` quando a fonte for insuficiente.

## Gatilho e escopo

Ativar quando o usuário fornecer (ou pedir curso a partir de):

- Texto livre, artigo, livro, notas, chat exportado
- URL (fazer fetch na web se necessário)
- Código, documentação técnica, README
- Transcrição de vídeo/áudio/podcast
- Planilha, slides, PDF (conteúdo colado ou descrito)
- Tema vago ("quero um curso sobre X")

**Não** exigir que o usuário defina público, duração ou formato — inferir e oferecer variantes.

---

## Fluxo obrigatório (7 fases)

Copie o checklist e marque cada fase antes de entregar:

```
Progresso:
- [ ] F1 — Ingestão e mapa da fonte
- [ ] F2 — Perfis de público e caminhos
- [ ] F3 — Resultados de aprendizagem (Bloom)
- [ ] F4 — Arquitetura do curso
- [ ] F5 — Produção das unidades
- [ ] F6 — Avaliação e certificação
- [ ] F7 — Auto-verificação final
```

### F1 — Ingestão e mapa da fonte

1. **Identificar tipo de entrada** e extrair o máximo de estrutura possível.
2. Se for URL e o conteúdo não estiver no chat → buscar na web (`WebFetch` / pesquisa).
3. Produzir **Mapa da Fonte** (sempre, mesmo que curto):

```markdown
## Mapa da Fonte

- **Tipo**: [texto | url | código | transcrição | misto]
- **Tema central**: uma frase
- **Subtemas detectados**: lista numerada
- **Pré-requisitos implícitos**: o que o leitor já precisa saber
- **Lacunas / ambiguidades**: itens com ⚠️ A VALIDAR
- **Vocabulário-chave**: 5–15 termos com definição em 1 linha
- **Claims verificáveis**: fatos que dependem da fonte (não extrapolar)
```

4. Se a fonte for enorme → priorizar por **impacto pedagógico** (fundamentos → aplicação → síntese), não por ordem do documento.

### F2 — Perfis de público e caminhos

Nunca assumir um único público. Gerar **3 trilhas** sobre o mesmo núcleo:

| Trilha        | Quem                            | Ritmo    | Profundidade                      |
| ------------- | ------------------------------- | -------- | --------------------------------- |
| **Essencial** | Iniciante absoluto, pouco tempo | Rápido   | Só o necessário para agir         |
| **Padrão**    | Intermediário, uso profissional | Moderado | Teoria + prática equilibradas     |
| **Mestre**    | Avançado, quer domínio          | Profundo | Edge cases, trade-offs, extensões |

Para cada trilha, definir em 3 linhas:

- **Motivação** (por que aprender isso agora)
- **Pré-requisitos explícitos** (o que revisar antes, com links internos ao curso)
- **Entrega esperada** (o que o aluno consegue fazer ao final)

Se o usuário indicar público específico (crianças, executivos, técnicos), **recalibrar** as três trilhas — não eliminar a flexibilidade; ajustar linguagem, exemplos e avaliações.

### F3 — Resultados de aprendizagem (Bloom)

Por trilha, escrever **4–8 resultados** mensuráveis com verbos da taxonomia revisada de Bloom:

- Lembrar / Compreender → **Explicar**, **Resumir**, **Classificar**
- Aplicar / Analisar → **Implementar**, **Diagnosticar**, **Comparar**
- Avaliar / Criar → **Justificar**, **Projetar**, **Propor**

Formato obrigatório por resultado:
`Ao final, o aluno será capaz de [verbo] [objeto] [critério mensurável].`

Alinhar cada resultado a pelo menos uma avaliação na F6.

### F4 — Arquitetura do curso

Estrutura padrão (adaptar nomes ao domínio):

```
Curso: [Título claro, benefício explícito]
├── Módulo 0: Orientação e diagnóstico
├── Módulo 1..N: Unidades temáticas (1 conceito nuclear cada)
└── Módulo Final: Síntese, projeto integrador e próximos passos
```

**Regras de arquitetura:**

- Módulo 0: quiz diagnóstico + como navegar as 3 trilhas + glossário vivo
- Cada módulo: 3–7 aulas; duração estimada por aula (5–25 min de estudo ativo)
- Ratio recomendado por módulo: **30% exposição | 40% prática | 20% reflexão | 10% avaliação formativa**
- Inserir **pontes** entre módulos (1 parágrafo: "o que aprendemos → o que vem")

UDL em cada módulo — incluir pelo menos:

- 1 forma de **engajamento** (escolha: caso, desafio, debate, gamificação leve)
- 2 formas de **representação** (texto + diagrama/tabela/metáfora; vídeo opcional como roteiro)
- 2 formas de **expressão** (quiz + exercício aberto OU projeto + peer-review simplificado)

### F5 — Produção das unidades

Para **cada aula**, usar o template em [templates.md](templates.md) (seção "Template de Aula").

Regras de redação:

- Primeira frase = gancho (problema real ou pergunta)
- Parágrafos curtos; listas para procedimentos
- **Exemplo concreto** antes da abstração (inductive quando possível)
- **Anti-jargão**: termo técnico → definição inline na primeira ocorrência
- Incluir bloco `💡 Para qualquer público` com analogia cotidiana
- Incluir bloco `🔧 Prática` com passo a passo verificável
- Incluir bloco `⚡ Armadilhas comuns` (2–4 erros típicos)

Se a fonte for código: snippet comentado + exercício de modificação + critério de "feito".
Se a fonte for teórica: estudo de caso + mapa mental em texto + pergunta socrática.

### F6 — Avaliação e certificação

Por trilha, definir:

| Tipo        | Quantidade         | Função                              |
| ----------- | ------------------ | ----------------------------------- |
| Diagnóstica | 1 (M0)             | Posicionar o aluno na trilha certa  |
| Formativa   | 1 por módulo       | Feedback sem nota                   |
| Somativa    | 1 a cada 2 módulos | Verificar domínio                   |
| Integradora | 1 (final)          | Projeto ou estudo de caso holístico |

Cada avaliação precisa de:

- **Enunciado** claro
- **Rubrica** (4 níveis: Iniciante | Em desenvolvimento | Proficiente | Exemplar)
- **Gabarito orientativo** ou critérios de correção
- **Tempo estimado**

Oferecer **micro-certificação por módulo** (critério: ≥ Proficiente na formativa) e **certificado de curso** (critério: integradora + 80% das somativas).

### F7 — Auto-verificação final

Antes de entregar, responder internamente e corrigir falhas:

| Critério                                                           | ✓   |
| ------------------------------------------------------------------ | --- |
| Qualquer pessoa consegue começar pelo M0 sem conhecimento prévio?  |     |
| As 3 trilhas cobrem o mesmo núcleo com profundidade diferente?     |     |
| Todo resultado de aprendizagem tem avaliação alinhada?             |     |
| Há alternativa não-visual para conteúdo visual (texto descritivo)? |     |
| Nenhum fato inventado fora da fonte?                               |     |
| Progressão sem saltos (cada aula usa só o que veio antes)?         |     |
| Exercícios têm critério de sucesso objetivo?                       |     |
| Glossário cobre 100% dos termos técnicos usados?                   |     |
| Existe projeto integrador aplicável ao mundo real?                 |     |

Se ≥2 itens falharem → revisar antes de entregar.

---

## Formato de entrega

Entregar **sempre** nesta ordem:

1. **Resumo executivo** (≤ 150 palavras): para quem é, o que aprende, tempo total estimado por trilha
2. **Mapa da Fonte** (F1)
3. **Visão das trilhas** (F2) — tabela comparativa
4. **Currículo completo** — índice clicável em markdown (módulos → aulas)
5. **Conteúdo expandido** — pelo menos M0 + M1 completos; demais módulos podem seguir o template resumido **se** o usuário pedir versão compacta; caso contrário, expandir tudo
6. **Pacote de avaliações** (F6)
7. **Guia do instrutor** (opcional, 1 página): como facilitar, timing sugerido, FAQs

Ver templates completos em [templates.md](templates.md).

---

## Modos de operação

Detectar intenção e ajustar:

| Pedido do usuário                   | Ação                                                 |
| ----------------------------------- | ---------------------------------------------------- |
| "Curso completo" / sem qualificador | Fluxo 7 fases, tudo expandido                        |
| "Só estrutura / outline"            | F1–F4 + índice detalhado, sem aulas expandidas       |
| "Aula única sobre X"                | F1 resumido + 1 aula no template completo            |
| "Adaptar para [público]"            | Manter arquitetura, reescrever exemplos e avaliações |
| "A partir desta URL"                | Fetch → Mapa da Fonte → fluxo normal                 |
| "Tornar mais fácil/difícil"         | Mover conteúdo entre trilhas, não diluir qualidade   |

---

## Pesquisa externa

- **Pode e deve** pesquisar na internet para: validar fatos, complementar lacunas da fonte, exemplos atuais, boas práticas do domínio.
- **Não** precisa explorar arquivos locais do projeto para criar o curso.
- Citar fontes externas quando adicionar informação que não estava na entrada: `📎 Fonte: [título](url)`.

---

## Idioma e tom

- Idioma do curso = idioma do pedido do usuário (padrão: português brasileiro).
- Tom: claro, direto, respeitoso; evitar tom acadêmico excessivo salvo pedido explícito.
- Inclusão: exemplos diversos; evitar estereótipos; linguagem neutra quando possível.

---

## Recursos

- Templates de aula, módulo e avaliação: [templates.md](templates.md)
- Exemplos e anti-padrões: [examples.md](examples.md)
