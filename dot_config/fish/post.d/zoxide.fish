if not command -q zoxide
    return
end

set -gx _ZO_DATA_DIR "$XDG_DATA_HOME/zoxide"

zoxide init fish | source
