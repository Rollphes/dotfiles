if status is-interactive
    set -g FZF_CTRL_R_COMMAND ""

    if command -q fzf
        fzf --fish | source
    end
end