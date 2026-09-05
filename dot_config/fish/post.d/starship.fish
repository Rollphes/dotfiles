if not command -q starship
    return
end

set -gx STARSHIP_CONFIG "$XDG_CONFIG_HOME/starship.toml"
set -gx STARSHIP_CACHE "$XDG_CACHE_HOME/starship"

if set -q MSYSTEM
    set STARSHIP_CONFIG (cygpath -w "$STARSHIP_CONFIG")
    set STARSHIP_CACHE (cygpath -w "$STARSHIP_CACHE")
end

starship init fish | source
