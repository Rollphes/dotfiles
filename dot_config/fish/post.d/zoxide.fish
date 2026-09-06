if not command -q zoxide
    return
end

set -l init_file "$XDG_CACHE_HOME/fish/init/zoxide.fish"

if test -r "$init_file"
    source "$init_file"
else
    echo "fish: zoxide init cache missing; generating for this session" >&2
    zoxide init fish | source
end
