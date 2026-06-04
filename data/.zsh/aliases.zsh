# Aliases
# SECURITY NOTE: Avoid aliasing destructive commands (rm, mv, cp, chmod).
# LLMs assume standard command behavior when suggesting shell commands.
# Masked commands cause silent, unexpected data loss.

# **OBRIGATÓRIO** sempre usar `-ld` e `lad`. O argumento `-l` ou `la` sózinhos enganosamente exibem symlinks como pastas reais.
# alias ls='eza -ld --icons'
alias ls='eza -ld --icons'
alias l='eza -ld --icons'
alias ll='eza -lad --icons'
alias sudo='sudo '
alias apt='apt '
alias i='install'
alias atgr='antigravity'

# DANGER ZONE: eval executes arbitrary code from an external tool.
# Ensure zoxide is installed from a trusted source before enabling.
eval "$(zoxide init zsh)"

# NEVER: Do not add 'curl URL | bash' or 'wget | sh' patterns to this file.
