# Skill: acceptance-criteria

## Purpose

Produza **3–5 critérios de aceite mensuráveis e testáveis** para uma user story. Use formato Dado-Quando-Então (BDD) ou lista de verificação conforme o que for mais claro para a feature.

## Quando usar

Aplique após o skill `user-story` ter produzido a User story. A entrada é a User story + Clarified summary.

**Nunca invoque quando** a User story estiver ausente ou incompleta — volte ao `user-story` primeiro.

## Como aplicar

1. **Releia a User story e o Clarified summary.** Identifique:
   - O caminho principal de sucesso (happy path).
   - Casos de borda ou condições de limite mencionados ou implícitos.
   - Restrições explícitas ou itens fora do escopo.

2. **Escolha o formato:**
   - **Dado-Quando-Então** (preferido): quando o comportamento é baseado em interação, há um ator claro executando uma ação e o resultado é observável.
   - **Lista de verificação** (`- [ ]`): quando os critérios são baseados em propriedades (performance, segurança, acessibilidade, formato de dados) ou quando DQE seria forçado e artificial.

3. **Escreva 3–5 critérios.** Para cada critério:
   - Deve ser **testável** — um testador ou teste automatizado pode verificá-lo com pass/fail binário.
   - Deve ser **mensurável** — usa valores específicos, limites ou estados observáveis (não "rápido" mas "carrega em < 2 s").
   - Deve estar em **linguagem de negócio** — sem detalhes de implementação (sem SQL, nomes de componentes ou internos de API).
   - Deve ser **independente** — cada critério se sustenta sozinho e não é duplicata de outro.

4. **Lista de verificação de qualidade** antes de retornar:
   - [ ] No mínimo 3, no máximo 5 critérios (a menos que a feature seja trivial → mínimo 2).
   - [ ] Todo critério tem condição clara de pass/fail.
   - [ ] Nenhum critério descreve implementação — apenas comportamento observável ou resultado mensurável.
   - [ ] Nenhum critério duplicado ou redundante.
   - [ ] Casos de borda e condições de limite cobertos (não só o happy path).

## Opções de formato

**Dado-Quando-Então:**

```markdown
## Critérios de aceite

- [ ] **Dado** [contexto inicial], **quando** [ação ou evento], **então** [resultado esperado].
- [ ] **Dado** [contexto inicial], **quando** [ação ou evento], **então** [resultado esperado].
- [ ] **Dado** [contexto inicial], **quando** [ação ou evento], **então** [resultado esperado].
```

**Lista de verificação (para critérios não comportamentais):**

```markdown
## Critérios de aceite

- [ ] [Propriedade observável ou resultado mensurável.]
- [ ] [Propriedade observável ou resultado mensurável.]
- [ ] [Propriedade observável ou resultado mensurável.]
```

**Misto (mais comum):**

```markdown
## Critérios de aceite

- [ ] **Dado** usuário logado com pedido confirmado, **quando** o checkout é concluído, **então** um e-mail de confirmação é enviado em até 60 segundos.
- [ ] **Dado** o e-mail de confirmação, **quando** o usuário o abre, **então** ele contém: número do pedido, itens comprados, valor total e link de rastreamento.
- [ ] **Dado** falha no envio do e-mail, **quando** ocorre erro no servidor de e-mail, **então** a compra é registrada normalmente e o sistema tenta reenvio em até 5 minutos.
- [ ] O e-mail é enviado para o endereço cadastrado na conta do usuário, não para um e-mail inserido no checkout.
```

## Exemplos

**User story:** Como usuário logado, quero receber um e-mail de confirmação ao concluir uma compra para ter certeza de que meu pedido foi registrado.

**Critérios de aceite:**

- [ ] **Dado** usuário logado com pedido no carrinho, **quando** o checkout é finalizado com pagamento aprovado, **então** um e-mail de confirmação é enviado em até 60 segundos.
- [ ] **Dado** o e-mail de confirmação, **quando** o usuário o abre, **então** ele contém: número do pedido, lista de itens, valor total e data estimada de entrega.
- [ ] **Dado** endereço de e-mail inválido na conta, **quando** o sistema tenta enviar a confirmação, **então** um alerta é registrado no sistema e a compra permanece confirmada.
- [ ] **Dado** falha temporária no servidor de e-mail, **quando** o envio falha, **então** o sistema realiza até 3 tentativas com intervalo de 5 minutos antes de registrar falha definitiva.

## Nunca invoque quando

- A User story estiver ausente — aplique `user-story` primeiro.
- A solicitação for escrever critérios de aceite para uma story já totalmente especificada — verifique se os critérios já atendem à lista de verificação de qualidade antes de sobrescrever.
