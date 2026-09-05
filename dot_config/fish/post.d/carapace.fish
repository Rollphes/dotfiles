if status is-interactive
    set -gx CARAPACE_BRIDGES 'bash,zsh,fish,inshellisense'

    if command -q carapace
        carapace _carapace fish | source
    end
end