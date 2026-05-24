# Exemplos — Curso Absoluto

## Exemplo 1: Entrada mínima (tema vago)

**Usuário**: "Crie um curso sobre git para qualquer pessoa."

**Agente (resumo do que fazer)**:

1. F1: Mapa da Fonte inferido (controle de versão, commits, branches, merge, remoto)
2. F2: Trilhas — Essencial (uso solo), Padrão (colaboração), Mestre (rebase, hooks, workflows)
3. F3: Resultados com verbos mensuráveis por trilha
4. F4–F7: Currículo 6 módulos + M0 diagnóstico + avaliações com rubrica
5. Pesquisar na web apenas se precisar validar comportamento de comandos específicos

---

## Exemplo 2: URL como fonte

**Usuário**: "Transforme https://example.com/docs em curso."

**Agente**:

1. `WebFetch` na URL
2. Mapa da Fonte a partir do conteúdo real (não inventar seções)
3. Marcar `⚠️ A VALIDAR` se a página estiver incompleta
4. Curso com mesmo índice lógico, mas pedagogicamente reordenado (fundamentos primeiro)

---

## Exemplo 3: Trecho de código

**Entrada**: 40 linhas de uma API REST em Python.

**Adaptação**:

- M0: quiz — "já programei?" / "conheço HTTP?"
- M1: HTTP e REST (analogia: garçom do restaurante)
- M2: linha a linha do código com exercício "mude o endpoint e prediga o resultado"
- M3: erros comuns (404, 500, validação)
- Projeto integrador: mini-API própria com rubrica

---

## Exemplo 4: Pedido só de outline

**Usuário**: "Só a estrutura, 4 módulos, tema: fotografia."

**Agente**: Entregar F1 Mapa + F2 trilhas + F4 currículo detalhado (títulos de aulas + resultados + tempos), **sem** expandir aulas. Mencionar: "Peça 'expandir Módulo 2' para conteúdo completo."

---

## Exemplo 5: Adaptação de público

**Usuário**: "Refaça para crianças de 10–12 anos."

**Agente**:

- Manter arquitetura e resultados (ajustar verbos para idade)
- Trocar exemplos por jogos, histórias, desafios curtos
- Avaliações: menos texto, mais desenho/classificação
- Trilha Mestre → desafios criativos extras, não conteúdo adulto

---

## Anti-exemplos (não fazer)

| Ruim                            | Por quê                   | Correto                              |
| ------------------------------- | ------------------------- | ------------------------------------ |
| Um único nível "para todos"     | Ignora variabilidade real | 3 trilhas sobre o mesmo núcleo       |
| Lista de tópicos sem atividades | Não é curso, é índice     | Cada aula com prática + checagem     |
| Avaliação só com nota numérica  | Sem feedback              | Rubrica 4 níveis                     |
| Inventar dados da fonte         | Perde confiança           | ⚠️ A VALIDAR ou pesquisa com citação |
| Paredes de texto                | Exclui cognitivamente     | Parágrafos curtos + UDL              |
