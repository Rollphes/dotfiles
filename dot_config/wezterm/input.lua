local appearance = require 'appearance'
local help = require 'help'

local M = {}

function M.apply(config, wezterm)
  local act = wezterm.action

  config.mouse_bindings = {
    {
      event = {
        Down = {
          streak = 1,
          button = 'Right',
        },
      },
      mods = 'NONE',
      action = act.PasteFrom 'Clipboard',
    },
  }

  config.keys = {
    {
      key = 'V',
      mods = 'CTRL|SHIFT',
      action = act.PasteFrom 'Clipboard',
    },
    {
      key = 'Insert',
      mods = 'SHIFT',
      action = act.PasteFrom 'Clipboard',
    },
    {
      key = 'B',
      mods = 'CTRL|SHIFT',
      action = appearance.background_inspect_action(wezterm),
    },
    {
      key = '?',
      mods = 'CTRL|SHIFT',
      action = help.action(wezterm),
    },
  }
end

return M
