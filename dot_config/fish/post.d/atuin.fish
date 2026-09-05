if not command -q atuin
    return
end

set -gx ATUIN_CONFIG_DIR "$XDG_CONFIG_HOME/atuin"

if set -q MSYSTEM
    set ATUIN_CONFIG_DIR (cygpath -w "$ATUIN_CONFIG_DIR")
end

atuin init fish --disable-up-arrow --disable-ai | source
