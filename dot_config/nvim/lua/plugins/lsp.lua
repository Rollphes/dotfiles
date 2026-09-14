local function find_upward(start, names)
    local git_root = vim.fs.root(start, ".git")

    return vim.fs.find(names, {
        path = start,
        upward = true,
        stop = git_root and vim.fs.dirname(git_root) or vim.uv.os_homedir(),
        limit = 1,
    })[1]
end

local function file_contains(path, pattern)
    if not path then
        return false
    end

    local ok, lines = pcall(vim.fn.readfile, path)
    if not ok then
        return false
    end

    return table.concat(lines, "\n"):match(pattern) ~= nil
end

local function disable_formatting(client)
    client.server_capabilities.documentFormattingProvider = false
    client.server_capabilities.documentRangeFormattingProvider = false
end


-- ------------------------------------------------------------
-- PowerShell
-- ------------------------------------------------------------

local powershell_es_tool = "github:PowerShell/PowerShellEditorServices"
local powershell_es_ready = false

if vim.fn.executable("mise") == 1 and vim.fn.executable("pwsh") == 1 then
    local result = vim.system(
        { "mise", "where", powershell_es_tool },
        { text = true }
    ):wait()

    local bundle_path = vim.fs.normalize(vim.trim(result.stdout or ""))

    if result.code == 0 and bundle_path ~= "" then
        local start_script = vim.fs.joinpath(
            bundle_path,
            "PowerShellEditorServices",
            "Start-EditorServices.ps1"
        )

        if vim.fn.filereadable(start_script) == 1 then
            vim.lsp.config("powershell_es", {
                bundle_path = bundle_path,
            })

            powershell_es_ready = true
        end
    end
end

if powershell_es_ready then
    vim.lsp.enable("powershell_es")
else
    vim.notify_once(
        "PowerShell LSP is unavailable; apply the dotfiles and run `mise install`.",
        vim.log.levels.WARN
    )
end


-- ------------------------------------------------------------
-- JSON / YAML schema catalog
-- ------------------------------------------------------------

vim.lsp.config("jsonls", {
    settings = {
        json = {
            schemas = require("schemastore").json.schemas(),
            validate = {
                enable = true,
            },
        },
    },
})

vim.lsp.config("yamlls", {
    settings = {
        yaml = {
            schemaStore = {
                enable = false,
                url = "",
            },
            schemas = require("schemastore").yaml.schemas(),
        },
    },
})


-- ------------------------------------------------------------
-- Rust
-- ------------------------------------------------------------

vim.lsp.config("rust_analyzer", {
    settings = {
        ["rust-analyzer"] = {
            check = {
                command = "clippy",
            },
        },
    },
})


-- ------------------------------------------------------------
-- Go
-- ------------------------------------------------------------

vim.lsp.config("gopls", {
    settings = {
        gopls = {
            staticcheck = true,
            analyses = {
                nilness = true,
                unusedparams = true,
                unusedwrite = true,
                useany = true,
            },
        },
    },
})


-- ------------------------------------------------------------
-- JavaScript / TypeScript lint authorities
-- ------------------------------------------------------------

-- Formatting is owned by Conform.
-- ESLint remains responsible for diagnostics, fixes and code actions.
vim.lsp.config("eslint", {
    settings = {
        format = false,
    },
})

-- Biome provides diagnostics/code actions.
-- Formatting is deliberately owned by Conform.
vim.lsp.config("biome", {
    on_attach = function(client)
        disable_formatting(client)
    end,
})


-- ------------------------------------------------------------
-- Python
-- ------------------------------------------------------------

-- basedpyright owns semantic analysis / type checking.
-- Ruff is enabled only for projects which explicitly adopt Ruff.
vim.lsp.config("ruff", {
    root_dir = function(bufnr, on_dir)
        local filename = vim.api.nvim_buf_get_name(bufnr)

        if filename == "" then
            return
        end

        local start = vim.fs.dirname(filename)

        local ruff_config = find_upward(start, {
            "ruff.toml",
            ".ruff.toml",
        })

        if ruff_config then
            on_dir(vim.fs.dirname(ruff_config))
            return
        end

        local pyproject = find_upward(start, {
            "pyproject.toml",
        })

        if pyproject and file_contains(pyproject, "%[tool%.ruff[%].]") then
            on_dir(vim.fs.dirname(pyproject))
        end
    end,

    on_attach = function(client)
        -- basedpyright remains the semantic/hover authority.
        client.server_capabilities.hoverProvider = false

        -- Conform owns formatting.
        disable_formatting(client)
    end,
})


-- ------------------------------------------------------------
-- Enable
-- ------------------------------------------------------------

vim.lsp.enable({
    -- JavaScript / TypeScript semantic
    "ts_ls",

    -- JavaScript / TypeScript lint authorities.
    -- Their upstream root detection prevents activation outside
    -- projects which explicitly use them.
    "eslint",
    "oxlint",
    "biome",

    -- Rust
    "rust_analyzer",

    -- Python
    "basedpyright",
    "ruff",

    -- Go
    "gopls",

    -- Web / structured data
    "html",
    "cssls",
    "jsonls",
    "taplo",
    "vue_ls",
    "svelte",
    "yamlls",

    -- Configuration / scripting
    "lua_ls",
    "bashls",
    "fish_lsp",

    -- Other existing language support
    "glsl_analyzer",
    "intelephense",
    "marksman",
})
