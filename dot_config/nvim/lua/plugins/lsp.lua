local powershell_es_tool = "github:PowerShell/PowerShellEditorServices"
local powershell_es_ready = false

if vim.fn.executable("mise") == 1 and vim.fn.executable("pwsh") == 1 then
    local result = vim.system({ "mise", "where", powershell_es_tool }, { text = true }):wait()
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

vim.lsp.enable({
    "ts_ls",
    "rust_analyzer",
    "basedpyright",

    "html",
    "cssls",
    "jsonls",
    "taplo",

    "lua_ls",
    "gopls",

    "vue_ls",
    "svelte",

    "yamlls",
    "bashls",
    "fish_lsp",

    "glsl_analyzer",
    "intelephense",

    "marksman",
})
