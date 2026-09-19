local fzf = require("fzf-lua")
local config = require("fzf-lua.config")
local trouble_actions = require("trouble.sources.fzf").actions

fzf.setup({})

config.defaults.actions.files["ctrl-t"] = trouble_actions.open
