if not command -q fzf
    return
end

set -g FZF_CTRL_R_COMMAND ""

fzf --fish | source
