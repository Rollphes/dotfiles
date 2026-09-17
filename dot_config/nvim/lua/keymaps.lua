vim.keymap.set("n", "-", "<CMD>Oil<CR>", {
    desc = "Open parent directory",
})

vim.keymap.set("n", "<leader>n", "<Cmd>Navbuddy<CR>", {
    desc = "Open symbol navigator",
})

vim.keymap.set("n", "<leader>m", function()
    require("treesj").toggle()
end, {
    desc = "Toggle split/join",
})

vim.keymap.set({ "n", "v" }, "<leader>f", function()
    require("conform").format({
        async = true,
        lsp_format = "fallback",
    })
end, {
    desc = "Format buffer",
})

vim.keymap.set("n", "<leader>t", function()
    require("terminal").toggle()
end, {
    desc = "Toggle integrated terminal",
})

vim.keymap.set("t", "<C-w>", "<C-\\><C-n><C-w>", {
    desc = "Use window commands from terminal",
})

local git = require("git")

vim.keymap.set("n", "<leader>gs", git.toggle_source_control, {
    desc = "Toggle Git source control",
})

vim.keymap.set("n", "<leader>gd", "<Cmd>CodeDiff file HEAD<CR>", {
    desc = "Git diff current file",
})

vim.keymap.set("n", "<leader>gf", git.toggle_file_history, {
    desc = "Toggle Git file history",
})

vim.keymap.set("n", "<leader>gl", git.toggle_line_history, {
    desc = "Toggle Git line history",
})

vim.keymap.set("x", "<leader>gl", git.toggle_selected_line_history, {
    desc = "Toggle Git selected-line history",
})
