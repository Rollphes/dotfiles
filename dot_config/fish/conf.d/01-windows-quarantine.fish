if set -q MSYSTEM
    set -gx APPDATA "$HOME/.winprofile/AppData/Roaming"
    set -gx LOCALAPPDATA "$HOME/.winprofile/AppData/Local"
end
