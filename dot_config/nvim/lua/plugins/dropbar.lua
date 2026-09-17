local bar = require("dropbar.bar")
local sources = require("dropbar.sources")
local utils = require("dropbar.utils")

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
