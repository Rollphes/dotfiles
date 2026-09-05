if not set -q MSYSTEM
    return
end

set -gx APPDATA "$HOME/.winprofile/AppData/Roaming"
set -gx LOCALAPPDATA "$HOME/.winprofile/AppData/Local"
