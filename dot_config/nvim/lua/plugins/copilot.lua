local mise_root = vim.trim(
    vim.fn.system({
        "mise",
        "where",
        "npm:@github/copilot-language-server",
    })
)

if vim.v.shell_error ~= 0 or mise_root == "" then
    error("@github/copilot-language-server is not installed by mise")
end

local matches = vim.fn.globpath(
    mise_root,
    "**/dist/language-server.js",
    false,
    true
)

local server_path = matches[1]

if not server_path then
    error("Copilot language-server.js was not found under " .. mise_root)
end

require("copilot").setup({
    panel = {
        enabled = false,
    },

    suggestion = {
        enabled = false,
    },

    nes = {
        enabled = false,
    },

    copilot_node_command = vim.fn.exepath("node"),

    server = {
        type = "nodejs",
        custom_server_filepath = server_path,
    },
})
