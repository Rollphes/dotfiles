if not command -q carapace
    return
end

set -gx CARAPACE_BRIDGES 'bash,zsh,fish,inshellisense'

set -l init_file "$XDG_CACHE_HOME/fish/init/carapace.fish"

if test -r "$init_file"
    source "$init_file"
else
    echo "fish: carapace init cache missing; generating for this session" >&2
    carapace _carapace fish | source
end
