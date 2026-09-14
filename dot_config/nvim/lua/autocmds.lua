-- ------------------------------------------------------------
-- Filetype refinement
-- ------------------------------------------------------------

vim.filetype.add({
    pattern = {
        [".*/%.github/workflows/.*%.yml"] = "yaml.ghaction",
        [".*/%.github/workflows/.*%.yaml"] = "yaml.ghaction",
    },
})


-- ------------------------------------------------------------
-- Create missing parent directories on save
-- ------------------------------------------------------------

vim.api.nvim_create_autocmd("BufWritePre", {
    callback = function(args)
        if args.match:match("^%w+://") then
            return
        end

        local dir = vim.fn.fnamemodify(args.file, ":p:h")

        if vim.fn.isdirectory(dir) == 0 then
            vim.fn.mkdir(dir, "p")
        end
    end,
})


-- ------------------------------------------------------------
-- Supplemental CLI lint
-- ------------------------------------------------------------

vim.api.nvim_create_autocmd("BufWritePost", {
    callback = function(args)
        if args.match:match("^%w+://") then
            return
        end

        require("plugins.lint").try_lint()
    end,
})


-- ------------------------------------------------------------
-- Terminal windows
-- ------------------------------------------------------------

vim.api.nvim_create_autocmd({ "TermOpen", "BufWinEnter" }, {
    callback = function(args)
        if vim.bo[args.buf].buftype ~= "terminal" then
            return
        end

        vim.wo.number = false
        vim.wo.relativenumber = false
        vim.wo.signcolumn = "no"
        vim.wo.foldcolumn = "0"
        vim.wo.cursorline = false
        vim.wo.list = false
    end,
})
