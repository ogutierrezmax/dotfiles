# Path to Oh My Zsh installation.
export ZSH="$HOME/.oh-my-zsh"

# Theme
ZSH_THEME="powerlevel10k/powerlevel10k"

# Plugins
plugins=(tmux git zsh-autosuggestions zsh-syntax-highlighting)

# Plugin configurations
ZSH_TMUX_AUTOSTART=false
ZSH_TMUX_AUTOCONNECT=true


# Load Oh My Zsh
source $ZSH/oh-my-zsh.sh
