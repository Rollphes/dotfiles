if not command -q fzf
    return
end

set -g FZF_CTRL_R_COMMAND ""

set -l init_file "$XDG_CACHE_HOME/fish/init/fzf.fish"

if test -r "$init_file"
    source "$init_file"
else
    echo "fish: fzf init cache missing; generating for this session" >&2
    fzf --fish | source
end
