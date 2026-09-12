local disabled_keys = {
    "<Up>",
    "<Down>",
    "<Left>",
    "<Right>",
}

for _, key in ipairs(disabled_keys) do
    vim.keymap.set({ "n", "v", "x", "i" }, key, "<Nop>")
end

vim.keymap.set("n", "-", "<CMD>Oil<CR>", {
    desc = "Open parent directory",
})
