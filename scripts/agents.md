# Documentação e Manutenção de Scripts

Este documento descreve a organização técnica dos scripts deste repositório e serve como guia de manutenção tanto para desenvolvedores humanos quanto para agentes de IA.

## Organização da Biblioteca (`dotfiles-lib.sh`)

A biblioteca central de funções utilitárias reside em `scripts/dotfiles-lib.sh`. Ela é projetada para ser modular e extensível.

### Diretriz de Crescimento e Modularização
- **Manutenção**: Atualmente, as funções estão centralizadas para facilitar o acesso inicial.
- **Evolução**: Caso a biblioteca cresça significativamente (ex: ultrapasse 500-600 linhas ou misture muitas responsabilidades), ela deve ser dividida em módulos especializados na pasta `scripts/`:
    - `git-utils.sh`: Para funções relacionadas a versionamento.
    - `link-utils.sh`: Para gerenciamento de links simbólicos.
    - `ui-utils.sh`: Para componentes de interface e menus.

### Padrões de Código
- **Namespace**: Todas as funções públicas da biblioteca devem manter o prefixo `dotfiles_` para evitar colisões de escopo quando carregadas por outros scripts.
- **Portabilidade**: Scripts devem ser escritos preferencialmente em Bash seguindo o padrão `set -euo pipefail`.
