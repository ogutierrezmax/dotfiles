---
name: pattern-generalizer
description: "Força a abstração de padrões genéricos antes de implementar soluções, evitando viés ao problema específico. Use sempre que o usuário mencionar 'generalizar', 'padrão reutilizável', 'solução genérica', 'abstrair padrão', 'reutilizável', 'evitar viés', 'não hardcodar', 'parametrizar', ou pedir que uma solução funcione para cenários semelhantes além do caso específico apresentado."
---

# Generalização de Padrões

Quando o usuário pede uma solução para um problema concreto mas quer que ela seja genérica o suficiente para funcionar em cenários semelhantes, há uma tendência natural de se enviesar ao problema específico — usando nomes, constantes e lógica acoplados ao caso apresentado. Esta skill existe para quebrar esse viés.

## Por que isso acontece

LLMs tendem a "espelhar" o pedido do usuário. Se o usuário diz "crie um script que renomeia fotos .jpg adicionando a data", a saída natural inclui `jpg` hardcoded, variáveis chamadas `photo` e lógica que só funciona para aquele cenário. O resultado funciona para o caso pedido, mas quebra no momento em que o usuário tenta adaptar para `.png`, `.pdf` ou qualquer outra variação do mesmo tipo de problema.

O objetivo não é ignorar o caso concreto — é usá-lo como *instância* de um padrão mais amplo.

## Processo

### 1. Identificar a classe de problema

Antes de escrever qualquer código, responda internamente:

- **Qual é a operação abstrata?** (ex: "renomear arquivos segundo um padrão" em vez de "renomear fotos jpg")
- **Quais partes do pedido são variáveis?** (extensão do arquivo, padrão de renomeação, diretório-alvo)
- **Quais partes são constantes estruturais?** (a necessidade de iterar sobre arquivos, aplicar transformação no nome, preservar a extensão)

### 2. Parametrizar

Nomear tudo pelo **papel que cumpre**, não pelo **valor específico** do pedido:

- Variáveis: `fileExtension` em vez de `jpg`, `targetItems` em vez de `photos`
- Funções: `renameByPattern(dir, pattern, extension)` em vez de `renameJpgWithDate()`
- Constantes configuráveis: extrair valores que o usuário mencionou como parâmetros com defaults sensatos

### 3. Teste do cenário vizinho

Perguntar-se: **se o input fosse diferente mas o problema fosse do mesmo tipo, esta solução funcionaria sem alteração?**

Exemplos de cenário vizinho:
- O usuário pediu para `.jpg` → funcionaria para `.png` sem mudar código?
- O usuário pediu validação de CPF → funcionaria para CNPJ trocando apenas as regras?
- O usuário pediu parser de CSV → funcionaria para TSV trocando apenas o delimitador?

Se a resposta for "não", há acoplamento ao caso específico que precisa ser extraído como parâmetro.

### 4. Implementar com o caso concreto como default

Agora sim, implementar. O caso concreto do usuário deve aparecer como **valores default ou exemplo de uso**, não como lógica embutida:

```
# Genérico: aceita qualquer extensão, qualquer padrão
def rename_files(directory, extension="jpg", pattern="{date}_{original}"):
    ...

# Uso para o caso do usuário:
rename_files("./photos", extension="jpg", pattern="{date}_{name}")
```

### 5. Auto-verificação

Reler o resultado e checar cada um destes sinais de viés:

- [ ] Há nomes de variáveis/funções que só fazem sentido para o caso específico?
- [ ] Há valores hardcoded que deveriam ser parâmetros?
- [ ] Os testes/exemplos só validam o caso pedido, ou cobrem variações?
- [ ] A documentação/comentários descrevem o padrão geral ou apenas o caso?
- [ ] Alguém com um problema *semelhante mas diferente* conseguiria usar isso sem reescrever?

Se qualquer resposta for "sim" nos três primeiros ou "não" nos dois últimos, refatorar antes de entregar.

## Exemplos

### Ruim — acoplado ao caso específico

```python
def calculate_book_shipping(book_weight):
    """Calcula frete para livros."""
    if book_weight < 0.5:
        return 5.90
    elif book_weight < 2.0:
        return 12.50
    else:
        return 18.00

# Só funciona para livros, com faixas hardcoded
```

### Bom — padrão extraído, caso concreto como uso

```python
def calculate_shipping(weight, rate_table):
    """Calcula frete para qualquer item baseado em tabela de faixas."""
    for max_weight, price in sorted(rate_table):
        if weight < max_weight:
            return price
    return rate_table[-1][1]

# Uso para livros (o caso original):
BOOK_RATES = [(0.5, 5.90), (2.0, 12.50), (float('inf'), 18.00)]
shipping = calculate_shipping(book_weight, BOOK_RATES)

# Uso para eletrônicos (cenário vizinho — zero alteração no código):
ELECTRONICS_RATES = [(1.0, 15.00), (5.0, 35.00), (float('inf'), 60.00)]
shipping = calculate_shipping(item_weight, ELECTRONICS_RATES)
```

## Antipadrões

- **Nomes do domínio no código genérico**: `processInvoice()` quando a lógica é "processar documento com campos-chave" → use `processDocument(fields)` 
- **Hardcodar regras de negócio**: `if country == "BR"` dentro de uma função que deveria receber regras como parâmetro
- **Testes que validam só o caso**: um teste que verifica CPF `123.456.789-09` mas não testa o *mecanismo* com outros formatos
- **Comentários que descrevem o caso, não o padrão**: `# Calcula ICMS para São Paulo` em vez de `# Aplica alíquota regional ao valor base`

## Quando NÃO generalizar

Nem tudo precisa ser genérico. Não aplique esta skill quando:

- O usuário **explicitamente** pediu algo específico e descartável ("me dá um one-liner rápido pra isso")
- A generalização adicionaria complexidade sem benefício real (ex: um script de migração que vai rodar uma única vez)
- O domínio é tão específico que não existem "cenários vizinhos" plausíveis

Na dúvida, pergunte ao usuário: "Quer uma solução específica para este caso ou algo reutilizável para cenários semelhantes?"
