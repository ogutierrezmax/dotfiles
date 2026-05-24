# Padrões de Critério de Aceitação por Tipo de Tarefa

Critérios de aceitação vagos são o maior causador de loops de correção.
Use estes padrões como ponto de partida para cada tipo de passo.

---

## Regra geral

Um bom critério de aceitação tem esta estrutura:

> **Dado** [estado inicial / input], **quando** [ação], **então** [resultado verificável].

Nunca use: "código limpo", "bem estruturado", "fácil de ler", "seguindo boas práticas".
Sempre use: valores concretos, comportamentos observáveis, estado mensurável.

---

## Por tipo de tarefa

### Criar função/método novo

```
- [ ] A função existe no arquivo `[caminho]` com a assinatura `[assinatura exata]`
- [ ] Quando chamada com `[input válido]`, retorna `[output esperado]`
- [ ] Quando chamada com `[input inválido/nulo]`, retorna/lança `[comportamento]`
- [ ] A função NÃO tem efeitos colaterais além de `[efeito esperado se houver]`
- [ ] Nenhum outro arquivo foi modificado
```

### Adicionar endpoint de API

```
- [ ] `[MÉTODO] /[rota]` responde com status `[código]` quando `[condição de sucesso]`
- [ ] Responde com status `[código de erro]` quando `[condição de erro]`
- [ ] O body de resposta tem o schema: `{ [campo]: [tipo], ... }`
- [ ] A rota está registrada no router em `[arquivo]`
- [ ] Validação de input rejeita `[campo obrigatório ausente]` com status 400
- [ ] A rota requer autenticação / não requer autenticação [escolha um]
```

### Criar componente de UI

```
- [ ] O componente renderiza sem erros com as props mínimas: `{ [prop]: [valor] }`
- [ ] Quando [ação do usuário], [comportamento visual/callback]
- [ ] Com a prop `[prop de estado]` como `[valor]`, exibe `[elemento/texto]`
- [ ] Com a prop `[prop de estado]` como `[outro valor]`, exibe `[outro elemento/texto]`
- [ ] O componente não faz chamadas de API diretamente (se for presentational)
- [ ] Props obrigatórias: `[lista]` — props opcionais com default: `[lista]`
```

### Migration de banco de dados

```
- [ ] A migration roda sem erro em banco limpo: `[comando]`
- [ ] O rollback executa sem erro: `[comando de down]`
- [ ] A tabela/coluna `[nome]` existe após a migration com os campos: `[lista]`
- [ ] Dados existentes na tabela `[nome]` não foram perdidos ou corrompidos
- [ ] Índices criados: `[lista]` (verifique com `[comando de verificação]`)
```

### Refatoração (sem mudança de comportamento)

```
- [ ] Os testes existentes em `[arquivo de teste]` passam sem modificação
- [ ] A assinatura pública de `[função/classe]` não mudou
- [ ] O output para os inputs `[lista de inputs de teste]` é idêntico ao anterior
- [ ] Nenhuma dependência nova foi introduzida
- [ ] O arquivo `[refatorado]` tem menos de `[N]` linhas (se o objetivo era reduzir tamanho)
```

### Integração com serviço externo

```
- [ ] Com as credenciais válidas em `.env`, a chamada a `[endpoint]` retorna status 200
- [ ] Em caso de timeout (> [N]ms), o erro é capturado e relançado como `[tipo de erro]`
- [ ] Em caso de resposta 4xx, o erro é loggado com `[informações]` e não causa crash
- [ ] Credenciais NÃO estão hardcodadas — lidas de `process.env.[NOME_VAR]`
- [ ] A integração tem retry com backoff para status `[429/503]`
```

### Escrever testes

```
- [ ] Todos os cenários listados na seção Casos de Borda têm pelo menos um teste
- [ ] Cada teste é independente (não depende de estado de outro teste)
- [ ] Mocks são usados para `[dependências externas]` — não há chamadas reais
- [ ] O coverage da função testada é >= [N]%  (ou: todos os branches são cobertos)
- [ ] Os testes rodam em < [N] segundos
- [ ] `[comando de teste]` passa com 0 falhas
```

---

## Critérios de verificação de contorno

Inclua sempre ao menos um critério que verifica o que NÃO deveria ter acontecido:

```
- [ ] Nenhum arquivo fora da lista `[arquivos do passo]` foi modificado
- [ ] Nenhuma dependência foi adicionada ao `package.json` / `requirements.txt`
- [ ] Nenhum `console.log` / `print` de debug foi deixado no código
- [ ] Nenhum secret ou credencial aparece no código
- [ ] A função não altera estado global
```

---

## Checklist de qualidade do critério

Antes de finalizar a seção de critérios, verifique:

- [ ] Cada critério é verificável sem ambiguidade (sim ou não, nunca "depende")
- [ ] Existe pelo menos 1 critério para o caminho feliz
- [ ] Existe pelo menos 1 critério para falha/borda
- [ ] Existe pelo menos 1 critério de contorno (o que NÃO deve ter mudado)
- [ ] Nenhum critério usa palavras subjetivas (limpo, elegante, simples, bom)
- [ ] Os critérios podem ser verificados sem rodar um sistema inteiro (unitários preferíveis)
