# History settings
HISTFILE=~/.zsh_history  # File where history is saved
HISTSIZE=10000           # Commands in session memory
SAVEHIST=10000           # Commands preserved on disk

setopt HIST_IGNORE_DUPS       # Ignore consecutive duplicates
setopt HIST_IGNORE_SPACE      # Commands with leading space are not saved
setopt SHARE_HISTORY          # Share history between terminals
setopt HIST_VERIFY            # Review command before executing with !!
setopt HIST_EXPIRE_DUPS_FIRST  # Delete duplicates first when reaching limit
