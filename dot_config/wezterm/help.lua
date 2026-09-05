local M = {}

function M.action(wezterm, choices)
  return wezterm.action.InputSelector {
    title = 'WezTerm Keybindings',
    description = 'Esc: close',
    choices = choices,
    action = wezterm.action_callback(function() end),
  }
end

return M
