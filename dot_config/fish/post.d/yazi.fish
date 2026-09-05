if set -q MSYSTEM
    set -gx YAZI_CONFIG_HOME (cygpath -w "$XDG_CONFIG_HOME/yazi")
else
    set -gx YAZI_CONFIG_HOME "$XDG_CONFIG_HOME/yazi"
end
