require("vim._core.ui2").enable({})

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
