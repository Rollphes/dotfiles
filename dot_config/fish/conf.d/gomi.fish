function rm --description 'move to the gomi trash; never fall back to the real rm'
    if command -q gomi
        command gomi $argv
        return $status
    end

    return 127
end