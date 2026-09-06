function __pj_preview --argument-names repository
    if not test -d "$repository"
        printf '󰅖  Repository not found\n%s\n' "$repository"
        return
    end

    printf '󰉋  PROJECT\n'
    printf '%s\n' (path basename "$repository")
    printf '%s\n\n' "$repository"

    set -l git_status (env LC_ALL=C.UTF-8 git -c core.quotepath=false -C "$repository" status --short --branch 2>/dev/null)
    set -l git_status_code $status
    if test $git_status_code -ne 0; or not set -q git_status[1]
        printf '󰊢  STATUS\n'
        printf '󰅖  Unavailable\n'
        return
    end

    printf '  BRANCH\n'
    printf '%s\n\n' (string replace -r '^## ' '' -- "$git_status[1]")

    printf '󰊢  CHANGES\n'
    if set -q git_status[2]
        printf '%s\n' $git_status[2..-1]
    else
        printf '󰄬  Clean\n'
    end
end
