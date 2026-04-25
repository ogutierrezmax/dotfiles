# Aliases
# SECURITY NOTE: Avoid aliasing destructive commands (rm, mv, cp, chmod).
# LLMs assume standard command behavior when suggesting shell commands.
# Masked commands cause silent, unexpected data loss.
alias ls='eza --icons'
alias l='eza -l --icons'
alias ll='eza -lah --icons'
alias sudo='sudo '
alias apt='apt '
alias i='install'
alias atgr='antigravity'

# DANGER ZONE: eval executes arbitrary code from an external tool.
# Ensure zoxide is installed from a trusted source before enabling.
eval "$(zoxide init zsh)"

# NEVER: Do not add 'curl URL | bash' or 'wget | sh' patterns to this file.
