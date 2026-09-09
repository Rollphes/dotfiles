require("kanagawa").setup({
    transparent = true,
    terminalColors = true,
    dimInactive = false,
    undercurl = true,

    commentStyle = { italic = true },
    keywordStyle = { italic = false },
    statementStyle = { bold = true },
    functionStyle = {},
    typeStyle = {},
})

vim.cmd.colorscheme("kanagawa-wave")
