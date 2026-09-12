local cmp = require("blink.cmp")

cmp.build():pwait()

cmp.setup({
    keymap = {
        preset = "super-tab",
    },

    completion = {
        documentation = {
            auto_show = true,
        },
    },

    sources = {
        default = {
            "lsp",
            "path",
            "snippets",
            "buffer",
        },
    },

    fuzzy = {
        implementation = "rust",
    },
})
