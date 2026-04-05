---
name: seamless-integration
description: "Integra conteúdo novo em arquivos existentes de forma orgânica, como se sempre tivesse feito parte do arquivo. Use sempre que o usuário pedir para adicionar, incluir, inserir, complementar, expandir ou enriquecer conteúdo em um arquivo que já existe — especialmente documentos, markdown, código, configurações ou textos narrativos. Também use quando o usuário reclamar que algo foi 'colado', 'injetado' ou ficou 'desconexo' no arquivo."
---

# Integração Orgânica de Conteúdo

Quando você precisa adicionar conteúdo a um arquivo existente, o resultado deve ser indistinguível de um arquivo escrito inteiramente por uma única pessoa, de uma só vez. O leitor nunca deve perceber onde o conteúdo original termina e o novo começa.

## Por que isso importa

Um bloco de texto simplesmente colado no meio de um arquivo quebra a coesão: muda o tom, repete conceitos já cobertos, ignora a hierarquia de seções, ou introduz terminologia diferente para as mesmas coisas. Isso força o usuário a reescrever manualmente para harmonizar. O objetivo desta skill é eliminar esse retrabalho.

## Processo

### 1. Ler o arquivo inteiro antes de editar

Não comece a escrever antes de ter lido o arquivo completo. Ao ler, extraia mentalmente:

- **Estrutura**: hierarquia de títulos/seções, ordem lógica, padrão de numeração
- **Voz**: tom (formal/informal/técnico), pessoa gramatical (nós/você/impessoal), tempo verbal
- **Terminologia**: termos-chave que o arquivo usa para conceitos recorrentes (não invente sinônimos)
- **Formatação**: estilo de listas (bullets vs numeradas), uso de negrito/itálico, tamanho médio dos parágrafos, espaçamento entre seções
- **Padrões repetidos**: se cada seção segue um template (ex: título → parágrafo introdutório → lista de itens → exemplo), o conteúdo novo deve seguir o mesmo template

### 2. Decidir onde posicionar

O conteúdo novo raramente pertence "no final" do arquivo. Encontre o ponto onde ele se encaixa na progressão lógica do documento:

- Se o arquivo segue uma narrativa (contexto → problema → solução → resultados), insira no ponto correto dessa narrativa
- Se é uma lista ou catálogo, insira na posição que respeita a ordenação existente (alfabética, cronológica, por prioridade, por complexidade)
- Se é código, respeite agrupamentos lógicos (imports juntos, funções relacionadas próximas, exports no final)

### 3. Tecer, não colar

Ao escrever o novo conteúdo:

- **Espelhe** o nível de detalhe das seções vizinhas — se cada seção tem 2 parágrafos, não escreva 6
- **Reuse** a terminologia exata do arquivo — se o documento diz "usuário", não alterne para "utilizador" ou "user"
- **Mantenha** a mesma pessoa gramatical e tempo verbal
- **Adapte** o nível hierárquico dos títulos ao contexto onde está inserindo (se está dentro de uma seção H2, use H3, não H2)
- **Conecte** com transições naturais quando o conteúdo antes e depois precisar fluir — não crie ilhas isoladas

### 4. Ajustar o entorno

A inserção pode exigir pequenos ajustes no conteúdo que já existia:

- Atualizar uma frase introdutória que listava "três aspectos" e agora são quatro
- Ajustar uma transição que dizia "por fim" mas agora não é mais o fim
- Adicionar uma referência cruzada de outra seção para a nova
- Renumerar itens se a lista era numerada

Esses ajustes são obrigatórios — sem eles o arquivo denuncia a emenda.

### 5. Revisar como leitor

Antes de entregar, releia o trecho editado junto com pelo menos 2-3 parágrafos/seções antes e depois. Pergunte-se: "se eu lesse isso pela primeira vez, notaria uma costura?" Se sim, ajuste.

## Antipadrões (o que não fazer)

- Inserir blocos com tom ou formato diferente do restante do arquivo
- Adicionar separadores visuais (linhas horizontais, comentários tipo "--- NOVO ---") que não existiam antes
- Duplicar informação que já consta em outra seção
- Quebrar a progressão lógica do documento (ex: inserir um conceito avançado antes das definições básicas)
- Criar uma nova seção de nível superior quando o conteúdo deveria ser uma subseção
- Usar vocabulário ou jargão diferente do que o arquivo já estabeleceu

## Exemplos

**Ruim** — bloco injetado sem integração:

```markdown
## Benefícios
- Rápido
- Confiável

## Novas funcionalidades adicionadas
Aqui estão as novas funcionalidades que foram incluídas:
- Dashboard analytics
- Exportação CSV
```

**Bom** — conteúdo integrado organicamente:

```markdown
## Benefícios
- Rápido
- Confiável
- Visibilidade sobre métricas de uso via dashboard de analytics
- Exportação de dados em CSV para análise externa
```
