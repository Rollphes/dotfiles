if not command -q atuin
    return
end

set -gx ATUIN_CONFIG_DIR (cygpath -w "$XDG_CONFIG_HOME/atuin")

atuin init fish --disable-up-arrow --disable-ai | source