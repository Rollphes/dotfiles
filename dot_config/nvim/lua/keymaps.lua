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
