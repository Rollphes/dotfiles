local wk = require("which-key")

wk.setup({
    preset = "modern",

    delay = 300,

    triggers = {
        { "<auto>", mode = "nxso" },
        { "g",      mode = { "n", "v" } },
        { "<C-w>",  mode = "n" },
    },

    win = {
        no_overlap = false,
        col = math.huge,
        row = -2,

        width = {
            min = 30,
            max = 60,
        },

        height = {
            min = 4,
            max = 25,
        },

        border = "rounded",
        padding = { 1, 2 },
        title = false,
    },

    layout = {
        width = {
            min = 20,
            max = 40,
        },
        spacing = 3,
    },

    plugins = {
        marks = true,
        registers = true,

        spelling = {
            enabled = true,
            suggestions = 20,
        },

        presets = {
            operators = true,
            motions = true,
            text_objects = true,
            windows = true,
            nav = true,
            z = true,
            g = true,
        },
    },

    show_help = false,
    show_keys = true,
})

wk.add({
    { "gr", group = "LSP", mode = "n" },
})
