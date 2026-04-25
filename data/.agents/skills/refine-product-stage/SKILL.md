---
name: refine-product-stage
description: >-
  Audita e refina artefatos de uma etapa de produto existente contra padrões de
  mercado, preenchendo lacunas e reorganizando estrutura. Use quando o usuário
  pedir revisão de documentação de produto legada, auditoria de /docs/product/,
  ou alinhamento de uma etapa já criada.
---

# Refinar etapa de produto existente

**Quando usar:** artefatos criados **antes** de um processo estruturado; se a skill `create-product-stage` tiver sido seguida, o refinamento tende a ser mínimo.

Referência conceitual: [taxonomia-processo-criacao.md](../../../taxonomia-processo-criacao.md).

## 1. Mapeamento do estado atual

- Identificar qual etapa refinar e onde estão os arquivos.
- Ler **todos** os arquivos relevantes (ferramentas de leitura/listagem do projeto).
- Entender: monólito vs. vários arquivos, localização, nomenclatura.
- **Saída:** mapa do que existe.

## 2. Pesquisa de padrões de mercado

- `web_search` por artefatos essenciais atuais para o nome da etapa.
- Priorizar fontes recentes e fiáveis; ajustar quantidade ao tamanho do projeto.
- **Saída:** lista de referência para comparação.

## 3. Lacunas e qualidade

- Comparar o existente com a referência de mercado:
  - **Lacunas estruturais:** artefatos ou secções em falta.
  - **Superficialidade:** templates com campos vazios, descrições rasas.
  - **Consolidação / divisão:** oportunidades de unir ou separar documentos.
  - **Arquitetura de informação:** pastas, hierarquia, arquivos soltos.
  - **Maturidade:** terminologia desatualizada, necessidade de reordenação/renumeração.
- **Saída:** diagnóstico estruturado.

## 4. Proposta de refatoração

- Plano explícito: mudanças estruturais; novos artefatos; aprofundamento de conteúdo; renomes e ordem; atualização de referências cruzadas e índices.
- **Aprovação do utilizador antes de executar.**
- **Saída:** plano aprovado.

## 5. Execução

- Aplicar mudanças aprovadas (mover, criar, renomear, reordenar).
- Ir além do cosmético: remover stubs, preencher lacunas, densificar análise.
- Incluir notas de nomenclatura quando houver variantes de mercado:

  ```markdown
  > **Nota sobre Nomenclatura:** No mercado este artefato também é conhecido como [variações]…
  ```

- Atualizar em cascata índices principais para evitar links quebrados.
- **Saída:** etapa consistente e navegável.

## 6. Verificação final

- Confirmar que arquivos e pastas batem certo com o plano.
- Garantir que não restam placeholders genéricos intencionais.
- Validar índices (ex. `index.md`) contra o sistema de arquivos.
- **Saída:** relatório conciso das alterações ao utilizador.
