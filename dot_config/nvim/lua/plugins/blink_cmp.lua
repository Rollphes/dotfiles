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
            "copilot",
        },

        providers = {
            copilot = {
                name = "Copilot",
                module = "blink-cmp-copilot",
                async = true,
                score_offset = 100,

                transform_items = function(_, items)
                    local CompletionItemKind =
                        require("blink.cmp.types").CompletionItemKind

                    local kind = #CompletionItemKind + 1
                    CompletionItemKind[kind] = "Copilot"

                    for _, item in ipairs(items) do
                        item.kind = kind
                    end

                    return items
                end,
            },
        },
    },

    appearance = {
        kind_icons = {
            Copilot = "",
            Text = "",
            Method = "",
            Function = "",
            Constructor = "",
            Field = "",
            Variable = "",
            Property = "",
            Class = "",
            Interface = "",
            Struct = "",
            Module = "",
            Unit = "",
            Value = "",
            Enum = "",
            EnumMember = "",
            Keyword = "",
            Constant = "",
            Snippet = "",
            Color = "",
            File = "",
            Reference = "",
            Folder = "",
            Event = "",
            Operator = "",
            TypeParameter = "",
        },
    },

    fuzzy = {
        implementation = "rust",
    },
})
