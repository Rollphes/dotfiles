
if not command -q starship
    return
end

set -gx STARSHIP_CONFIG (cygpath -w "$XDG_CONFIG_HOME/starship.toml")
set -gx STARSHIP_CACHE (cygpath -w "$XDG_CACHE_HOME/starship")

starship init fish | source