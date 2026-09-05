if not command -q starship
    return
end

if set -q MSYSTEM
    set -gx STARSHIP_CONFIG (cygpath -w "$XDG_CONFIG_HOME/starship.toml")
    set -gx STARSHIP_CACHE (cygpath -w "$XDG_CACHE_HOME/starship")
else
    set -gx STARSHIP_CONFIG "$XDG_CONFIG_HOME/starship.toml"
    set -gx STARSHIP_CACHE "$XDG_CACHE_HOME/starship"
end

starship init fish | source
