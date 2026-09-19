local blink_kind_icons =
    require("blink.cmp.config").appearance.kind_icons

require("trouble").setup({
    focus = false,

    icons = {
        kinds = blink_kind_icons,
    },

    modes = {
        diagnostics = {
            win = {
                position = "bottom",
            },
        },

        lsp = {
            win = {
                position = "bottom",
            },
        },

        symbols = {
            win = {
                position = "right",
                size = 0.25,
            },

            filter = {
                any = {
                    ft = {
                        "help",
                        "markdown",
                    },

                    kind = {
                        "Class",
                        "Constructor",
                        "Enum",
                        "EnumMember",
                        "Field",
                        "Function",
                        "Interface",
                        "Method",
                        "Module",
                        "Namespace",
                        "Package",
                        "Property",
                        "Struct",
                        "Trait",
                        "Variable",
                        "Constant",
                    },
                },
            },
        },
    },
})
