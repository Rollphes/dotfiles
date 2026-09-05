# Windows compatibility quarantine
#
# Development Session から起動した Windows-native tool が
# APPDATA / LOCALAPPDATA に fallback した場合、
# Windows Host profile を汚染せず MSYS2 HOME 内へ隔離する。
#
# ここに生成された state は「正常な保存先」ではなく、
# tool-specific storage behavior を調査するための signal として扱う。

set -gx APPDATA "$HOME/.winprofile/AppData/Roaming"
set -gx LOCALAPPDATA "$HOME/.winprofile/AppData/Local"