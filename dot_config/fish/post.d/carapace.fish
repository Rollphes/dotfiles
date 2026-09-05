if not command -q carapace
    return
end

set -gx CARAPACE_BRIDGES 'bash,zsh,fish,inshellisense'

carapace _carapace fish | source
