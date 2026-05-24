---
name: "sonar-ai-refactor"
description: "Analisa issues do SonarQube e gera planos de refatoração atômicos e numerados para execução por IA."
---

# Sonar AI Refactor Skill

Esta skill automatiza o ciclo de "Análise -> Planejamento -> Refatoração" usando dados do SonarQube. Ela organiza o trabalho em tarefas atômicas para garantir precisão e evitar regressões.

## 🚀 Fluxo de Trabalho

### 0. Sincronização e Autenticação (Obrigatório)
Antes de qualquer análise, a skill deve garantir que os dados estão atualizados e que possui acesso ao servidor.
1. **Verificar Token**: Checar se `sonar.token` está presente no `sonar-project.properties` ou se a variável de ambiente `SONAR_TOKEN` está definida.
2. **Solicitar Token**: Caso não exista, a skill **deve pedir ao usuário** o token do SonarQube.
3. **Salvar Token**: Após receber o token, a skill deve salvá-lo no arquivo `sonar-project.properties` (ou `.sonar-token`) para uso futuro.
4. **Executar Scanner**: Rodar `npm run sonar` (ou `sonar-scanner`).
5. **Validação**: Aguardar a finalização do processo.

### 1. Coleta de Dados
Após a sincronização, a skill busca as issues no SonarQube local.
- **API Endpoint**: `http://localhost:9000/api/issues/search?componentKeys=[PROJECT_KEY]&resolved=false`
- **Ação**: Ler o JSON retornado e mapear cada issue para o arquivo e linha correspondentes no projeto.

### 2. Estratégia de Atomicidade
A skill deve classificar as issues para decidir como separá-las em arquivos de plano:
- **INDIVIDUAL**: 
    - Issues de Complexidade Cognitiva (`S3776`).
    - Bugs Críticos ou Vulnerabilidades.
    - Qualquer issue que exija alteração lógica profunda.
- **BATCH (Agrupado)**:
    - Code Smells triviais (nomenclatura, variáveis não usadas, comentários) que ocorrem no mesmo arquivo.
- **ORDEM**:
    1. Refatoração estrutural (Complexidade).
    2. Bugs e Segurança.
    3. Limpeza de Smells triviais.

### 3. Organização de Arquivos
A skill deve criar uma pasta `.sonar/ai-plans/` na raiz do projeto e gerar os seguintes arquivos:

1. **`00_summary.md`**: Um resumo executivo de todas as tarefas, status atual e impacto esperado.
2. **`XX_nome_da_tarefa.md`**: Arquivos numerados (01, 02, 03...) contendo:
    - **Contexto**: Arquivo, linha e regra do Sonar.
    - **Objetivo**: O que deve ser alcançado.
    - **Instruções Técnicas**: Passos específicos para a IA executora.
    - **Critérios de Aceite**: Como validar que o problema foi resolvido.

### 4. Execução
Após gerar os planos, a skill deve:
- Perguntar ao usuário qual tarefa ele deseja iniciar.
- Ao iniciar uma tarefa, ler o conteúdo do arquivo `XX_...md` e usá-lo como o prompt principal para a modificação.
- Marcar a tarefa como concluída após a aplicação e validação.

## 🛠️ Comandos de Suporte
- Se o usuário pedir para "analisar o sonar", inicie o passo 1.
- Se o usuário pedir para "preparar os planos", execute o passo 2 e 3.
- Se o usuário pedir para "corrigir o sonar", siga o fluxo completo.

## ⚠️ Restrições
- Nunca tente corrigir todos os problemas de uma vez se envolverem lógica complexa.
- Sempre verifique se o arquivo alvo existe antes de gerar o plano.
- Prefira criar funções puras e pequenos componentes durante a refatoração.
