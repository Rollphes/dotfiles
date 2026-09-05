if status is-interactive
    set -gx _ZO_DATA_DIR "$XDG_DATA_HOME/zoxide"

    if command -q zoxide
        zoxide init fish | source
    end
end