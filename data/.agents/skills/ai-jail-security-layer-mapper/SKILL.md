---
name: ai-jail-security-layer-mapper
description: Para cada etapa do ai-jail, pergunta se existe outra ferramenta ou config no sistema que deveria ser configurada da mesma forma.
---

# AI Jail Security Layer Mapper

Para cada seção do `AI Jail - Anotado.md`, executar:

1. **Extrair** o conceito de segurança daquela etapa
2. **Perguntar**: "existe alguma ferramenta, aplicação ou configuração no sistema do usuário que lida com conceito semelhante e poderia/deveria ser configurada de forma igual ou similar?"
3. **Verificar** se essa config já existe e está sincronizada
4. **Gerar** a config se necessário
5. **Atualizar** a cópia local do anotado.md

---

## Checklist de Seções

- [ ] **Cabeçalho e introdução** — flags fundamentais do bwrap
- [ ] **Shebang e cabeçalho** — entrypoint do jail
- [ ] **Variáveis iniciais** — `PROJECT_DIR`, `TEMP_HOSTS`
- [ ] **Trap de limpeza** — `trap EXIT`
- [ ] **Descoberta do Mise** — detecção de runtime
- [ ] **Popula `/etc/hosts`** — bloqueio de DNS
- [ ] **Parsing de `--map` / `--rw-map`** — montagens extras via CLI
- [ ] **Inicialização do Mise** — preparação de ambiente
- [ ] **Deny-lists** — `DOTDIR_DENY`, `CONFIG_DENY`, `CACHE_DENY`
- [ ] **Diretórios com permissão de escrita** — `DOTDIR_RW`
- [ ] **Funções auxiliares** — `is_denied()`, `is_rw()`
- [ ] **Descoberta automática de dot-directories** — loop de montagem
- [ ] **Montagens explícitas de dotfiles** — `.gitconfig`, `.claude.json`
- [ ] **Esconde subdiretórios sensíveis** — `CONFIG_HIDE_MOUNTS`, `CACHE_HIDE_MOUNTS`
- [ ] **Overrides de `~/.local`** — `LOCAL_OVERRIDES`
- [ ] **Dispositivos GPU** — `GPU_MOUNTS`
- [ ] **Docker socket** — `DOCKER_MOUNT`
- [ ] **Memória compartilhada** — `SHM_MOUNT`
- [ ] **Passthrough de display** — X11 + Wayland
- [ ] **Montagem e execução do bwrap** — comando final
- [ ] **Modo de usar** — exemplos de uso
- [ ] **Configuração de permissões do Claude Code** — bloco JSON de permissões

---

## Arquivos da Skill

```
ai-jail-security-layer-mapper/
├── SKILL.md
└── AI-Jail-Anotado.md    # atualizado com descobertas
```
