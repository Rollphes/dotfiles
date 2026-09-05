if not command -q zoxide
    return
end

set -gx _ZO_DATA_DIR "$XDG_DATA_HOME/zoxide"

set -l init_file "$XDG_CACHE_HOME/fish/init/zoxide.fish"

if test -r "$init_file"
    source "$init_file"
else
    echo "fish: zoxide init cache missing; generating for this session" >&2
    zoxide init fish | source
end
