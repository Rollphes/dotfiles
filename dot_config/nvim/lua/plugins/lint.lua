local lint = require("lint")

local linters_by_ft = {}


-- ------------------------------------------------------------
-- Shell
-- ------------------------------------------------------------

if vim.fn.executable("shellcheck") == 1 then
    linters_by_ft.sh = { "shellcheck" }
    linters_by_ft.bash = { "shellcheck" }
end


-- ------------------------------------------------------------
-- GitHub Actions
-- ------------------------------------------------------------

if vim.fn.executable("actionlint") == 1 then
    linters_by_ft.ghaction = { "actionlint" }
end


-- ------------------------------------------------------------
-- Markdown
-- ------------------------------------------------------------

if vim.fn.executable("markdownlint-cli2") == 1 then
    linters_by_ft.markdown = { "markdownlint-cli2" }
end


-- ------------------------------------------------------------
-- Dockerfile
-- ------------------------------------------------------------

if vim.fn.executable("hadolint") == 1 then
    linters_by_ft.dockerfile = { "hadolint" }
end


lint.linters_by_ft = linters_by_ft

return lint
