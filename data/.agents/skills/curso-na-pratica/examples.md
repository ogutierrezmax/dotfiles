# Exemplos — Curso na Prática

## Exemplo 1: Tema vago

**Usuário**: "Quero um curso prático de git."

**Agente (resumo do que fazer)**:

1. F1: Mapa da Fonte — ações detectadas: criar repo, commitar, branchear, mergear, push
2. F2: Mapa de desafios — do "crie um arquivo e salve" até "resolva um conflito real"
3. F3: Cada desafio = ação primeiro, explicação depois ("o que faz" + "por que importa" + "e se pular")
4. F4: Projeto final — "resolva este cenário de conflito em um repo colaborativo"

---

## Exemplo 2: URL como fonte

**Usuário**: "Cria um curso prático a partir da docs do FastAPI."

**Agente**:

1. `WebFetch` na URL
2. Extrair **ações** da docs (criar endpoint, validar input, rodar server, testar)
3. Desafio 0: "rode este endpoint hello world em 3 linhas"
4. Desafios seguintes: cada um adiciona 1 feature da docs
5. Projeto final: "crie uma API com autenticação e validação"

---

## Exemplo 3: Código como fonte

**Entrada**: 40 linhas de uma API REST em Python.

**Abordagem**:

- Desafio 0: "rode o código e acesse / no browser"
- Desafio 1: "mude a rota de / para /api — o que mudou?"
- Desafio 2: "adicione um novo endpoint — o que quebrou? por quê?"
- Projeto final: "crie sua própria API com 3 endpoints relacionados"

---

## Exemplo 4: Só outline

**Usuário**: "Só a lista de desafios, tema: CSS."

**Agente**: Entregar F1 Mapa + F2 Mapa de Desafios (tabela com título, ação, conceito, tempo). **Sem** expandir desafios. Mencionar: "Peça 'expandir Desafio 2' para o conteúdo completo."

---

## Exemplo 5: Comparação com abordagem teórica

**Teórico (ruim para este contexto)**:
> "CSS (Cascading Style Sheets) é uma linguagem de folhas de estilo usada para descrever a apresentação de documentos HTML..."

**Prático (certo)**:
> **Faça isso**: Abra este arquivo HTML no browser. Agora adicione `<style>body { background: red; }</style>` no `<head>` e recarregue.
>
> **O que aconteceu**: O fundo ficou vermelho. O CSS manda o browser pintar elementos de um jeito diferente do padrão.
>
> **E se pular**: O site fica com a aparência padrão do browser — funciona, mas sem identidade visual.

---

## Anti-exemplos (não fazer)

| Ruim | Por quê | Correto |
| --- | --- | --- |
| Começar com definição teórica | O aluno quer fazer, não ler | Começar com "Faça isso:" |
| "Ao final desta lição o aluno será capaz de" | Linguagem acadêmica | "Você vai fazer X e ver Y acontecer" |
| Explicar 3 conceitos antes do primeiro passo | Sobrecarga cognitiva | 1 passo → 1 explicação curta |
| Projeto final com passo a passo | Vira tutorial, não desafio | Só objetivo + pistas opcionais |
| Múltiplas trilhas de dificuldade | Foco é prática, não segmentação | Um caminho: fazer |
| Blocos longos de teoria | O aluno curioso quer ação | Máx 3 frases por explicação |
