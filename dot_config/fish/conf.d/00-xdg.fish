if set -q MSYSTEM
    # Same authority as the Windows chezmoi destination, including native callers.
    set -gx HOME (cygpath -u "C:/msys64/home/$USERNAME")
end

set -gx XDG_CONFIG_HOME "$HOME/.config"
set -gx XDG_DATA_HOME "$HOME/.local/share"
set -gx XDG_STATE_HOME "$HOME/.local/state"
set -gx XDG_CACHE_HOME "$HOME/.cache"
