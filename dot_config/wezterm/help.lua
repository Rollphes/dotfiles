local M = {}

local choices = {
  { label = 'Paste       Right click           Clipboard paste' },
  { label = 'Paste       Ctrl+Shift+V          Clipboard paste' },
  { label = 'Paste       Shift+Insert          Clipboard paste' },
  { label = 'Appearance  Ctrl+Shift+B          Background Inspect' },
  { label = 'Workspace   Ctrl+Shift+P          Switch workspace' },
  { label = 'Workspace   Ctrl+Shift+P          Create workspace' },
  { label = 'Workspace   Ctrl+Shift+P          Rename workspace' },
  { label = 'Launcher    Right-click +         Profiles and domains' },
  { label = 'Help        Ctrl+Shift+?          This keybinding sheet' },
}

function M.action(wezterm)
  return wezterm.action.InputSelector {
    title = 'WezTerm Keybindings',
    description = 'Esc: close',
    choices = choices,
    action = wezterm.action_callback(function() end),
  }
end

return M
