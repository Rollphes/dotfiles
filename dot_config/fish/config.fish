if set -q fish_user_paths[1]
    fish_add_path --path --prepend $fish_user_paths
end

if status is-interactive
    for file in $XDG_CONFIG_HOME/fish/post.d/*.fish
        source $file
    end
end
