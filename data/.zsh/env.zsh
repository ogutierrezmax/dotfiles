# Environment variables
# SECURITY NOTE: DO NOT place sensitive information (API keys, passwords, tokens) in this file.
# This file is tracked by Git. For secrets, use a local file like ~/.zsh_local or ~/.env_private
# which should be added to your .gitignore if it's inside this repository.

# PATH deduplication (zsh-specific)
# `typeset -U path` marks the path array as "unique": zsh keeps only the first
# occurrence of each directory. It also scrubs a PATH already polluted by a
# parent shell (tmux, wezterm, shells spawned by opencode) — those used to
# re-prepend 5 entries on every nesting level. First-occurrence-wins keeps the
# precedence we want: a prepended tool still overrides a system binary.
# GOTCHA: uniqueness applies to ARRAY operations only. A scalar append such as
# `export PATH="$PATH:$dir"` is NOT deduped, so the lines below use the array
# form (`path=...` / `path+=...`), which is tied to PATH and stays exported.
typeset -U path
path=("$HOME/bin" "$HOME/.local/bin" /usr/local/bin "${path[@]}")
path+=("$HOME/.opencode/bin")

# NVM configuration
export NVM_DIR="$HOME/.nvm"

# External environment files
[ -f "$HOME/.local/bin/env" ] && . "$HOME/.local/bin/env"
