vim.keymap.set("n", "-", "<CMD>Oil<CR>", {
    desc = "Open parent directory",
})

vim.keymap.set("n", "<leader>m", function()
    require("treesj").toggle()
end, {
    desc = "Toggle split/join",
})
