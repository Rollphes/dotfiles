if not command -q atuin
    return
end

if set -q MSYSTEM
    set -gx ATUIN_CONFIG_DIR (cygpath -w "$XDG_CONFIG_HOME/atuin")
else
    set -gx ATUIN_CONFIG_DIR "$XDG_CONFIG_HOME/atuin"
end

atuin init fish --disable-up-arrow --disable-ai | source
