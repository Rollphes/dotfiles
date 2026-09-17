local gitsigns = require("gitsigns")

gitsigns.setup({
    current_line_blame = true,
    word_diff = false,

    watch_gitdir = {
        follow_files = true,
    },

    on_attach = function(bufnr)
        local function map(mode, lhs, rhs, desc)
            vim.keymap.set(mode, lhs, rhs, {
                buffer = bufnr,
                silent = true,
                desc = desc,
            })
        end

        map("n", "]h", function()
            gitsigns.nav_hunk("next")
        end, "Next Git hunk")

        map("n", "[h", function()
            gitsigns.nav_hunk("prev")
        end, "Previous Git hunk")

        map("n", "<leader>ga", gitsigns.stage_hunk, "Stage Git hunk")

        map("v", "<leader>ga", function()
            gitsigns.stage_hunk({
                vim.fn.line("."),
                vim.fn.line("v"),
            })
        end, "Stage selected Git hunk")

        map("n", "<leader>gr", gitsigns.reset_hunk, "Reset Git hunk")

        map("v", "<leader>gr", function()
            gitsigns.reset_hunk({
                vim.fn.line("."),
                vim.fn.line("v"),
            })
        end, "Reset selected Git hunk")

        map("n", "<leader>gp", gitsigns.preview_hunk, "Preview Git hunk")

        map("n", "<leader>gb", function()
            gitsigns.blame_line({
                full = true,
            })
        end, "Git blame current line")

        map(
            "n",
            "<leader>gB",
            gitsigns.toggle_current_line_blame,
            "Toggle Git line blame"
        )

        map(
            { "o", "x" },
            "ih",
            gitsigns.select_hunk,
            "Git hunk"
        )
    end,
})
