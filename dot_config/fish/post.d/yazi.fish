set -gx YAZI_CONFIG_HOME "$XDG_CONFIG_HOME/yazi"

if set -q MSYSTEM
    set YAZI_CONFIG_HOME (cygpath -w "$YAZI_CONFIG_HOME")
end
