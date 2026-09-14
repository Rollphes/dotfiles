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
