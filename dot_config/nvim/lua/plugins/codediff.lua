require("codediff").setup({
    diff = {
        layout = "side-by-side",

        cycle_next_hunk = true,
        cycle_next_file = true,

        -- gitsigns owns normal editing-buffer gutter signs.
        gutter_signs = false,

        jump_to_first_change = true,
        compact = false,
    },

    explorer = {
        position = "left",
        hidden = false,
        width = 40,

        auto_refresh = true,
        initial_focus = "explorer",

        -- VSCode Source Control pane-like changed-file tree.
        view_mode = "tree",
        flatten_dirs = true,
        indent_markers = true,

        visible_groups = {
            staged = true,
            unstaged = true,
            conflicts = true,
        },

        line_stats = {
            enabled = true,
            count_untracked = false,
        },
    },

    history = {
        position = "bottom",
        height = 15,
        initial_focus = "history",
        view_mode = "tree",
        date_format = "%ar",
    },
})
