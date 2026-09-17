local M = {}

local function close_codediff_if_open()
    local tabpage = vim.api.nvim_get_current_tabpage()
    local lifecycle = require("codediff.ui.lifecycle")

    if lifecycle.get_session(tabpage) then
        lifecycle.close(tabpage)
        return true
    end

    return false
end

function M.toggle_source_control()
    vim.cmd("CodeDiff")
end

function M.toggle_file_history()
    if close_codediff_if_open() then
        return
    end

    vim.cmd("CodeDiff history %")
end

function M.toggle_line_history()
    if close_codediff_if_open() then
        return
    end

    local line = vim.api.nvim_win_get_cursor(0)[1]

    vim.cmd(
        ("%d,%dCodeDiff history"):format(
            line,
            line
        )
    )
end

function M.toggle_selected_line_history()
    if close_codediff_if_open() then
        return
    end

    vim.cmd("'<,'>CodeDiff history")
end

return M
