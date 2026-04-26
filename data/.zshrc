# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# Modular configuration
# Each module is located in ~/.zsh/ directory
# SECURITY NOTE: Ensure these files are owned by your user and not world-writable.
# Be cautious when adding new modules suggested by LLMs; always review the content.
source ~/.zsh/env.zsh
source ~/.zsh/plugins.zsh
source ~/.zsh/history.zsh
source ~/.zsh/aliases.zsh

# User configuration
bindkey '^L' autosuggest-accept

# NVM script loading
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

# Powerlevel10k theme customization
# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh
source ~/powerlevel10k/powerlevel10k.zsh-theme

# Load local secrets and machine-specific overrides (not tracked by Git)
# SECURITY NOTE: Place API keys, tokens, and sensitive env vars in ~/.zsh_local
[ -f ~/.zsh_local ] && source ~/.zsh_local

