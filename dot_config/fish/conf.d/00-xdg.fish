if set -q MSYSTEM
    # Direct launches bypass msys2_shell.cmd, so restore the UCRT64 command roots
    # before any conf.d script or generated integration invokes MSYS2 tools.
    fish_add_path --global --prepend /ucrt64/bin /usr/bin

    # Same authority as the Windows chezmoi destination, including native callers.
    set -gx HOME "/home/$USERNAME"
end

set -gx XDG_CONFIG_HOME "$HOME/.config"
set -gx XDG_DATA_HOME "$HOME/.local/share"
set -gx XDG_STATE_HOME "$HOME/.local/state"
set -gx XDG_CACHE_HOME "$HOME/.cache"
