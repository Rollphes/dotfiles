vim.opt.showcmd = true
vim.opt.showcmdloc = "statusline"

require("lualine").setup({
    options = {
        theme = "auto",
        globalstatus = false,
    },

    sections = {
        lualine_a = { "mode" },
        lualine_b = { "branch", "diff", "diagnostics" },
        lualine_c = {},

        lualine_x = {
            {
                "%S",
                padding = { left = 1, right = 1 },
            },
            "filetype",
        },
        lualine_y = { "progress" },
        lualine_z = { "location" },
    },

    inactive_sections = {
        lualine_a = {},
        lualine_b = {},
        lualine_c = {},
        lualine_x = { "filetype" },
        lualine_y = {},
        lualine_z = { "location" },
    },
})
