# AGENTS.md — OpenCode Orchestrated Provider

## Propósito
Ponte de orquestração via protocolo ACP (Agent Client Protocol) entre o Hermes Agent e o OpenCode CLI local (`opencode acp`). Permite ao usuário utilizar modelos gratuitos e locais do OpenCode diretamente no Hermes sem necessidade de chaves de API.

## Diretrizes Invioláveis de Stealth (Non-Detection Policy)
O OpenCode CLI é ele próprio um agente autônomo com runtime interno. Sob **nenhuma hipótese** o OpenCode deve detectar que está sendo orquestrado por outro agente ou bot.

### 1. Zero Fingerprinting no ACP
- **Identificação do Cliente**: O parâmetro `clientInfo` no `initialize` JSON-RPC DEVE SEMPRE se passar por um editor padrão de mercado (ex.: `{"name": "vscode", "title": "Visual Studio Code", "version": "1.93.0"}`).
- **PROIBIDO**: Nunca usar `"name": "hermes"`, `"hermes-agent"`, `"nous"`, `"bot"` ou qualquer identificador de IA.

### 2. Proibição de Preâmbulos Meta-Agente
- **Nenhum preâmbulo de proxy**: NUNCA injetar frases como *"You are acting as backend for Hermes"*, *"Use ACP capabilities for Hermes"* ou similares no prompt.
- O OpenCode deve receber o prompt de forma tão natural quanto se um usuário humano estivesse digitando no terminal ou na IDE.

### 3. Sanitização de Mensagens e Personas
- **Expurgar Persona do Hermes**: Antes de enviar o histórico de mensagens (`_format_messages_as_prompt`), remover qualquer menção a *"You are Hermes Agent"*, *"built by Nous Research"*, links de documentação do Hermes ou skills do Hermes.
- **Instruções do Usuário**: Apenas diretrizes reais do usuário (ex.: "responda em português", "seja conciso") devem ser preservadas.
- **Single-turn Prompt**: Se a requisição contiver apenas uma mensagem de usuário, enviar o texto cru do usuário sem prefixos ou metadados.

### 4. Isolamento Total de Ferramentas (No Tool Leak)
- **Não injetar schemas de ferramentas externas**: NUNCA injetar schemas de ferramentas do Hermes (`web_search`, `terminal`, `browser_exec`) no prompt do OpenCode com blocos `<tool_call>`.
- O OpenCode possui seu próprio runtime de ferramentas. Injetar nomes de ferramentas do Hermes induz o modelo do OpenCode a tentar invocar ferramentas inexistentes no runtime local, gerando erros como *"No tool named X is currently available"*.
- Deixar o OpenCode resolver tarefas e pesquisas na web com seu próprio motor autônomo.

### 5. Higienização de Ambiente e Parâmetros
- **Variáveis de Ambiente**: Limpar qualquer variável com prefixo `HERMES_*` ou `NOUS_*` do dicionário `env` do subprocesso antes de executar `opencode`.
- **Caminhos de Diretório**: Nunca passar caminhos privados do Hermes (como `~/.hermes`) no parâmetro `location.directory` de chamadas de API do OpenCode.

## Comandos de Validação
- **Testar inferência limpa sem vazamentos**:
  ```bash
  /home/max/.hermes/tools/python-3.14.7+20260901-linux-x64/bin/python3 -I -c "
  import sys; sys.path.insert(0, '/home/max/.hermes/hermes-agent')
  import hermes_bootstrap, importlib.util
  spec = importlib.util.spec_from_file_location('c', 'plugins/model-providers/opencode-orchestrated/client.py')
  mod = importlib.util.module_from_spec(spec)
  spec.loader.exec_module(mod)
  client = mod.OpenCodeACPClient()
  res = client._create_chat_completion(model='opencode/big-pickle', messages=[{'role': 'user', 'content': 'Ping'}])
  print('Result:', res.choices[0].message.content)
  "
  ```
- **Auditar ausência de strings 'hermes' no prompt gerado**:
  ```bash
  python3 -c "
  import sys; sys.path.insert(0, 'plugins/model-providers/opencode-orchestrated')
  from client import _format_messages_as_prompt
  p = _format_messages_as_prompt([{'role': 'system', 'content': 'You are Hermes Agent'}, {'role': 'user', 'content': 'Hi'}])
  assert 'hermes' not in p.lower() and 'nous' not in p.lower(), 'VAZAMENTO DETECTADO!'
  print('Auditoria passou: 100% stealth!')
  "
  ```
