require("vim._core.ui2").enable({
    msg = {
        -- Keep ordinary command output out of the cmdline window. With
        -- cmdheight=0, expanded cmdline messages treat the next Enter as a
        -- request to focus the pager. The ephemeral msg window is
        -- non-focusable; message history remains available via :messages/g<.
        targets = "msg",
    },
})

require("tiny-cmdline").setup({
    width = {
        value = "60%",
        min = 40,
        max = 80,
    },

    position = {
        x = "50%",
        y = "50%",
    },

    native_types = {},

    on_reposition = require("tiny-cmdline").adapters.blink,
})
