# Environment variables
# SECURITY NOTE: DO NOT place sensitive information (API keys, passwords, tokens) in this file.
# This file is tracked by Git. For secrets, use a local file like ~/.zsh_local or ~/.env_private
# which should be added to your .gitignore if it's inside this repository.
export PATH=$HOME/bin:$HOME/.local/bin:/usr/local/bin:$PATH
export PATH=/home/alfo/.opencode/bin:$PATH

# NVM configuration
export NVM_DIR="$HOME/.nvm"

# External environment files
[ -f "$HOME/.local/bin/env" ] && . "$HOME/.local/bin/env"
