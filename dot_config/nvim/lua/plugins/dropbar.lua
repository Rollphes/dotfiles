local bar = require("dropbar.bar")
local configs = require("dropbar.configs")
local sources = require("dropbar.sources")
local utils = require("dropbar.utils")

local default_enable = configs.opts.bar.enable

local oil_source = {
    get_symbols = function(buf, _, _)
        local ok, oil = pcall(require, "oil")
        if not ok then
            return {}
        end

        local dir = oil.get_current_dir(buf)
        if not dir then
            return {}
        end

        dir = vim.fn.fnamemodify(dir, ":~")

        return {
            bar.dropbar_symbol_t:new({
                icon = "󰉋 ",
                name = dir,
                name_hl = "Directory",
            }),
        }
    end,
}

require("dropbar").setup({
    bar = {
        enable = function(buf, win, info)
            buf = vim._resolve_bufnr(buf)

            if
                vim.api.nvim_buf_is_valid(buf)
                and vim.api.nvim_win_is_valid(win)
                and vim.bo[buf].filetype == "oil"
            then
                return vim.fn.win_gettype(win) == ""
                    and vim.wo[win].winbar == ""
            end

            return default_enable(buf, win, info)
        end,

        sources = function(buf, _)
            if vim.bo[buf].filetype == "oil" then
                return {
                    oil_source,
                }
            end

            if vim.bo[buf].filetype == "markdown" then
                return {
                    sources.path,
                    sources.markdown,
                }
            end

            if vim.bo[buf].buftype == "terminal" then
                return {
                    sources.terminal,
                }
            end

            return {
                sources.path,
                utils.source.fallback({
                    sources.lsp,
                    sources.treesitter,
                }),
            }
        end,
    },
})
