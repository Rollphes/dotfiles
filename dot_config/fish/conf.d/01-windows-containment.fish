if not set -q MSYSTEM
    return
end

# HOME stays POSIX; native profile and temp resolvers receive Windows paths.
set -gx USERPROFILE (/usr/bin/cygpath.exe -w "$HOME")
set -gx APPDATA (/usr/bin/cygpath.exe -w "$XDG_CONFIG_HOME")
set -gx LOCALAPPDATA (/usr/bin/cygpath.exe -w "$XDG_DATA_HOME")
set -gx TEMP (/usr/bin/cygpath.exe -w /tmp)
set -gx TMP "$TEMP"
set -gx GHQ_ROOT "$HOME/ghq"
set -gx GOCACHE (/usr/bin/cygpath.exe -w "$XDG_CACHE_HOME/go-build")
set -gx NPM_CONFIG_CACHE (/usr/bin/cygpath.exe -w "$XDG_CACHE_HOME/npm")

set -gx MISE_CONFIG_DIR "$XDG_CONFIG_HOME/mise"
set -gx MISE_DATA_DIR "$XDG_DATA_HOME/mise"
set -gx MISE_STATE_DIR "$XDG_STATE_HOME/mise"
set -gx MISE_CACHE_DIR "$XDG_CACHE_HOME/mise"
set -gx MISE_TMP_DIR "$XDG_CACHE_HOME/mise/tmp"

# mise embeds aube for npm tools.
set -gx AUBE_CACHE_DIR "$XDG_CACHE_HOME/aube"
set -gx AUBE_STORE_DIR "$XDG_DATA_HOME/aube/store"

# uv follows Windows profile directories instead of XDG directories on Windows.
set -gx UV_CACHE_DIR "$XDG_CACHE_HOME/uv"
set -gx UV_TOOL_DIR "$XDG_DATA_HOME/uv/tools"
set -gx UV_PYTHON_INSTALL_DIR "$XDG_DATA_HOME/uv/python"

# zoxide uses the Windows local application data directory by default.
set -gx _ZO_DATA_DIR "$XDG_DATA_HOME/zoxide"
