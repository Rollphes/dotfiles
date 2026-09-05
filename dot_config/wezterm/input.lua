local appearance = require 'appearance'
local help = require 'help'

local M = {}

function M.apply(config, wezterm)
  local act = wezterm.action
  local help_choices = {
    { label = 'Paste       Right click           Clipboard paste' },
    { label = 'Paste       Ctrl+Shift+V          Clipboard paste' },
    { label = 'Paste       Shift+Insert          Clipboard paste' },
    { label = 'Appearance  Ctrl+Shift+B          Background Inspect' },
    { label = 'Help        Ctrl+Shift+?          This keybinding sheet' },
  }

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
      action = help.action(wezterm, help_choices),
    },
  }
end

return M
