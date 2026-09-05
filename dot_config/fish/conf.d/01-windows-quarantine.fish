# XDG Base Directory Specification
#
# Development Session 内の XDG-aware tool は、
# MSYS2 HOME を persistent storage の基準とする。
#
# Windows-native child process では MSYS2 runtime により
# C:/msys64/home/<user>/... へ path conversion される。

set -gx XDG_CONFIG_HOME "$HOME/.config"
set -gx XDG_DATA_HOME "$HOME/.local/share"
set -gx XDG_STATE_HOME "$HOME/.local/state"
set -gx XDG_CACHE_HOME "$HOME/.cache"