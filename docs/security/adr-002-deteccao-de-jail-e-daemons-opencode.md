# ADR-002: Detecção de Sandbox (Jail vs Host) e Isolamento de Daemons no OpenCode v2

- **Status**: Aceito
- **Data**: 2026-09-28
- **Contexto**: Integração entre o sandbox Bubblewrap (`ai-jail`), a CLI `opencode` (v2 com arquitetura cliente-servidor) e regras de segurança para agentes de IA.

---

## 1. Contexto do Problema

Com a atualização do **OpenCode v2**, a arquitetura deixou de ser monolítica e passou a adotar um modelo **Cliente-Servidor**:
- **Servidor (`opencode serve --service`)**: Roda em segundo plano (daemon persistente). É quem gerencia o SQLite, memória e **executa as chamadas de ferramentas e comandos bash**.
- **Cliente (`opencode` TUI / Desktop app)**: Interface gráfica/texto que apenas envia mensagens via HTTP/WebSocket para o servidor.

Essa mudança gerou dois desafios fundamentais de segurança e usabilidade:
1. **Conflito de Daemons**: Se a primeira sessão aberta no sistema rodasse em jail, o servidor de background nascia dentro do sandbox e aprisionava todas as sessões subsequentes (inclusive requisições com `--no-jail`). Se nascesse no host, sessões em jail conectavam ao servidor do host e bypassavam o sandbox sem aviso.
2. **Divergência de Sinais de Detecção**: O sinal `AI_EXECUTION_MODE` (variável de ambiente de software) expressa a intenção do cliente, enquanto o `hostname` (propriedade do namespace UTS do kernel Linux) reflete onde o comando realmente é executado.

---

## 2. Regra de Negócio: Hierarquia de Verdade (Kernel > Variável)

### Princípio Fundamental
> **O kernel não mente; variáveis de ambiente podem ser herdadas, exportadas ou repassadas via rede.**

Por isso, a detecção de execução em Sandbox segue uma hierarquia estrita:

1. **`hostname` é a verdade física do Kernel**:
   - O Bubblewrap isola o namespace UTS via `--unshare-uts --hostname "ai-sandbox"`.
   - Um processo sem privilégios dentro do sandbox **não tem permissão de kernel** para alterar o hostname de volta para o hostname do host (`debian`).
   - Se `hostname == "ai-sandbox"`, o código está **fisicamente confinado** no sandbox.
   - Se `hostname != "ai-sandbox"`, o código está **fisicamente executando no host**, independentemente de qualquer variável de ambiente.

2. **`AI_EXECUTION_MODE` é a declaração de intenção do usuário**:
   - `AI_EXECUTION_MODE=host`: Expressa a intenção deliberada do usuário de rodar em modo Host flexível (`--no-jail`).
   - `AI_EXECUTION_MODE=jail`: Expressa a intenção de rodar em modo Sandbox restrito.

---

## 3. Matriz de Estados e Tratamento de Divergência

| `hostname` | `AI_EXECUTION_MODE` | Estado Real | Comportamento do Agente / Sistema |
| :--- | :--- | :--- | :--- |
| `ai-sandbox` | `jail` | **JAIL Válido** | Aplica todas as regras estritas da Sandbox (tmpfs, deny-lists, sem comandos destrutivos). |
| `debian` (host) | `host` | **HOST Válido** | Aplica modo Host flexível (`--no-jail`). Persistência e ferramentas completas do host ativas. |
| `debian` (host) | `jail` | **Divergência Crítica (Falso Sandbox)** | O cliente pediu jail, mas conectou a um daemon no host. **Fisicamente é HOST**. O agente não deve assumir falso conforto de sandbox; o sistema precisa isolar os daemons. |
| `ai-sandbox` | `host` | **Divergência (Sandbox Forçado)** | O cliente pediu host, mas conectou a um daemon na jail. **Fisicamente é JAIL**. Comandos restritos falharão por falta de permissão de montagem. |


---

## 4. Decisão Arquitetural: Isolamento Estrito de Dois Daemons

Para eliminar as divergências da matriz acima, adotamos a arquitetura de **dois daemons independentes e simultâneos**:

```text
[ HOST LINUX ]
 ├── Daemon Host:
 │    ├── Porta: 49376 (ou padrão)
 │    ├── Config: ~/.config/opencode/service.json
 │    ├── State:  ~/.local/state/opencode/service.json
 │    └── Namespace: Nativo (hostname debian, AI_EXECUTION_MODE=host)
 │
 └── Daemon Jail:
      ├── Porta: 49380
      ├── Config: ~/.config/opencode-jail/service.json (montado sobre ~/.config/opencode)
      ├── State:  ~/.local/state/opencode-jail (montado sobre ~/.local/state/opencode)
      └── Namespace: Bubblewrap (hostname ai-sandbox, AI_EXECUTION_MODE=jail)
```

### Regras de Execução nos Wrappers:
1. `opencode --no-jail`:
   - Executa diretamente no host nativo (`~/.opencode/bin/opencode "$@"`).
   - Exporta `AI_EXECUTION_MODE=host`.
   - Conecta ao daemon persistente do host (porta 49376).
2. `opencode` (padrão):
   - Executa via `ai-jail`.
   - Se já estiver dentro de um sandbox (`AI_EXECUTION_MODE=jail`), executa o binário direto para evitar aninhamento acidental de Bubblewrap.
   - Conecta ao daemon persistente da jail (porta 49380).
   - Não compartilha nem sobrescreve os arquivos de serviço do host.

---

## 5. Consequências

### Positivas:
- **Segurança Real**: Elimina o risco de comandos em "jail" serem executados de forma invisível no host.
- **Preservação dos Benefícios da v2**: Sessões persistem em segundo plano ao fechar o terminal tanto no host quanto na sandbox.
- **Auditoria Transparente**: Agentes e scripts de auditoria têm clareza absoluta de contexto via `hostname` e `AI_EXECUTION_MODE`.

### Negativas / Custos:
- Daemons simultâneos consomem memória RAM independente (~150MB a 300MB cada).
- O histórico de sessões da jail e do host vivem em bancos de dados isolados.
