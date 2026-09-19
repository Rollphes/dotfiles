require("which-key").setup({
    preset = "modern",

    delay = 300,

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
            max = 16,
        },

        border = "rounded",
        padding = { 0, 1 },
        title = false,
    },

    layout = {
        width = {
            min = 20,
            max = 40,
        },
        spacing = 2,
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
