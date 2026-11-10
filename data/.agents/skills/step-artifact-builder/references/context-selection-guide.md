# Guia de Seleção de Contexto

Como escolher exatamente quais arquivos incluir no artefato — nem de mais, nem de menos.

---

## O Princípio

> **Inclua o menor conjunto de arquivos que permite à LLM entender o padrão e o contrato do que vai implementar.**

Contexto demais polui a atenção do modelo. Contexto de menos gera código incompatível.

---

## Árvore de decisão

```
Para cada arquivo candidato, pergunte:

1. A LLM precisa ler este arquivo para saber COMO implementar?
   (convenção de código, padrão arquitetural, estilo)
   → SIM: inclua

2. A LLM precisa ler este arquivo para saber O QUE implementar?
   (interface que vai usar, tipo que vai retornar, schema que vai seguir)
   → SIM: inclua

3. A LLM precisa ler este arquivo para saber O QUE NÃO FAZER?
   (lógica que não deve ser duplicada, função que não deve ser alterada)
   → SIM: inclua (mas pode ser só o trecho relevante)

4. O arquivo só é relevante para entender o domínio de negócio?
   → NÃO inclua — explique em prosa na seção Contexto do Sistema

5. O arquivo é grande e só uma função é relevante?
   → Inclua apenas a função + assinatura das funções vizinhas (com comentário de corte)
```

---

## Categorias de arquivo e quando incluir

### ✅ Sempre incluir
- Arquivo que será **modificado** pelo passo
- Arquivo com **interface/tipo/schema** que o novo código vai usar ou retornar
- Um arquivo existente como **exemplo de padrão** (o mais representativo do estilo do projeto)
- Arquivo de **configuração** se o passo depende de alguma configuração (env, di container, etc.)

### ⚠️ Incluir com critério
- Arquivo pai/base de uma classe que será estendida → inclua apenas a assinatura dos métodos relevantes
- Arquivo de teste existente → inclua apenas se o passo requer que os testes passem
- Arquivo de types/interfaces → inclua apenas os tipos que o novo código usa

### ❌ Nunca incluir
- Arquivos que não têm relação direta com o passo ("para dar contexto geral")
- Arquivos que a LLM reconheceria de cor (node_modules, bibliotecas populares)
- Duplicatas de padrões (se você já incluiu um exemplo de padrão, não precisa de 3)
- Arquivos de outros módulos que não interagem com este passo

---

## Técnicas de corte para arquivos grandes

### Corte por função relevante
```typescript
// ... [imports omitidos]
// ... [constructor e outros métodos omitidos]

// ↓ REFERÊNCIA DE PADRÃO — siga este estilo para a nova função
async processPayment(data: PaymentData): Promise<Result<Payment, PaymentError>> {
  // ... implementação ...
}

// ... [resto do arquivo omitido]
```

### Corte por interface pública
```typescript
// Apenas a interface pública — implementação omitida
export interface UserRepository {
  findById(id: string): Promise<User | null>
  save(user: User): Promise<void>
  delete(id: string): Promise<boolean>
}
```

### Corte por seção comentada
```python
# [arquivo: services/order_service.py — apenas a parte relevante]

class OrderService:
    def __init__(self, repo: OrderRepository, notifier: Notifier):
        # ... outros métodos omitidos

    def calculate_total(self, items: list[Item]) -> Decimal:
        """
        REFERÊNCIA: siga este padrão para a nova função de desconto
        """
        return sum(item.price * item.quantity for item in items)
```

---

## Heurística de tamanho total de contexto

| Total de linhas de código no contexto | Avaliação |
|--------------------------------------|-----------|
| < 200 linhas | Ideal — foco máximo |
| 200–500 linhas | Aceitável — verifique se tudo é necessário |
| 500–1000 linhas | Arriscado — tente cortar ou dividir o passo |
| > 1000 linhas | Problema — o passo provavelmente está grande demais |

---

## Armadilhas comuns

**"Vou incluir tudo para não faltar nada"**
→ A LLM perde foco. Inclua apenas o necessário e confie na instrução de Persona para o restante.

**"Não preciso incluir o arquivo que vou modificar, a LLM sabe como é"**
→ Sem o arquivo atual, a LLM não sabe o que já existe e pode duplicar ou conflitar lógica.

**"O arquivo é enorme, vou incluir o path e pedir para a LLM imaginar"**
→ A LLM vai inventar o conteúdo. Sempre inclua pelo menos a interface pública e os trechos relevantes.

**"Vou descrever o padrão em texto em vez de mostrar código"**
→ Código existente como exemplo é 10x mais eficaz que descrição em prosa para ensinar padrão.
