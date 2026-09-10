local treesitter = require("nvim-treesitter")

local parsers = {
    "bash",
    "blade",
    "c_sharp",
    "css",
    "fish",
    "glsl",
    "go",
    "html",
    "javascript",
    "json",
    "lua",
    "markdown",
    "markdown_inline",
    "php",
    "powershell",
    "python",
    "rust",
    "scss",
    "sql",
    "svelte",
    "toml",
    "tsx",
    "typescript",
    "vue",
    "yaml",
}

treesitter.install(parsers)

vim.treesitter.language.register("json", { "jsonc" })

vim.api.nvim_create_autocmd("FileType", {
    pattern = {
        "bash",
        "blade",
        "cs",
        "css",
        "fish",
        "glsl",
        "go",
        "html",
        "javascript",
        "javascriptreact",
        "json",
        "jsonc",
        "lua",
        "markdown",
        "php",
        "ps1",
        "python",
        "rust",
        "scss",
        "sql",
        "svelte",
        "toml",
        "typescript",
        "typescriptreact",
        "vue",
        "yaml",
    },
    callback = function()
        vim.treesitter.start()
    end,
})
