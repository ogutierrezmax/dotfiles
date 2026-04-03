# dotfiles

Configurações pessoais versionadas com symlinks para `~`.

## Estrutura

| Caminho | Conteúdo |
|--------|----------|
| `data/` | Arquivos de configuração (fonte dos links em `~`) |
| `config/` | Listas (`dotfile-names.list`, `packages.list`) |
| `scripts/` | Biblioteca e auxiliares (`dotfiles-lib.sh`, instalação em lote, UI do menu) |
| `docs/` | Notas e documentação |
| `scripts/install-dotfiles.sh` | Instala tudo: confirmação e criação dos symlinks |
| `dotfiles-menu.sh` | Menu: mostra o estado de cada entrada e instala por número |

Para incluir um novo dotfile: coloque-o em `data/` e acrescente o nome (relativo a `data/`) em `config/dotfile-names.list`.

## Uso

Instalar tudo de uma vez:

```bash
./scripts/install-dotfiles.sh
```

Menu interativo (o que já está linkado, o que falta, etc.):

```bash
./dotfiles-menu.sh
```
