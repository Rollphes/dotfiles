local M = {}

local function apply(expandtab, width, softtabstop)
    vim.opt_local.expandtab = expandtab
    vim.opt_local.tabstop = width
    vim.opt_local.shiftwidth = width
    vim.opt_local.softtabstop = softtabstop

    -- Restore the global fallback when this buffer changes filetype.
    local undo = 'setlocal expandtab< tabstop< shiftwidth< softtabstop<'
    vim.b.undo_ftplugin = vim.b.undo_ftplugin
        and (vim.b.undo_ftplugin .. ' | ' .. undo) or undo
end

function M.spaces(width)
    apply(true, width, width)
end

function M.tabs(width)
    -- Disable soft tab stops so Tab uses actual tab stops.
    apply(false, width, 0)
end

-- after/ftplugin runs during FileType; builtin EditorConfig applies later
-- on BufRead/BufNewFile in Neovim 0.12.5, overriding these input defaults.
return M
