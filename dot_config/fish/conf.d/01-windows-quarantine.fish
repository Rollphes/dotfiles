if not set -q MSYSTEM
    return
end

set -gx APPDATA "$HOME/.winprofile/AppData/Roaming"
set -gx LOCALAPPDATA "$HOME/.winprofile/AppData/Local"

# uv follows Windows profile directories instead of XDG directories on Windows.
set -gx UV_CACHE_DIR "$XDG_CACHE_HOME/uv"
set -gx UV_TOOL_DIR "$XDG_DATA_HOME/uv/tools"
set -gx UV_PYTHON_INSTALL_DIR "$XDG_DATA_HOME/uv/python"
