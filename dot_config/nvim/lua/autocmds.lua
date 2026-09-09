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
