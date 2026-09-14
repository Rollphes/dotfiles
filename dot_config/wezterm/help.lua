local M = {}

local choices = {
  { label = 'Tabs        Ctrl+Tab                 Next tab' },
  { label = 'Tabs        Ctrl+Shift+Tab           Previous tab' },
  { label = 'Tabs        Ctrl+Shift+T             New tab' },
  { label = 'Tabs        Ctrl+Shift+W             Close tab (confirm)' },
  { label = 'Tabs        Ctrl+Shift+1..9          Select tab (9 = last)' },
  { label = 'Tabs        Ctrl+Shift+PageUp/Down   Move tab left/right' },
  { label = 'Panes       Ctrl+Shift+Arrow         Focus pane' },
  { label = 'Panes       Ctrl+Shift+Alt+Arrow     Resize pane' },
  { label = 'Panes       Ctrl+Shift+Alt+%         Split left/right' },
  { label = 'Panes       Ctrl+Shift+Alt+"         Split top/bottom' },
  { label = 'Panes       Ctrl+Shift+Z             Toggle pane zoom' },
  { label = 'Workspace   Ctrl+Shift+P             Switch / Create / Rename via Command Palette' },
  { label = 'Launcher    Right-click +            Profiles and domains' },
  { label = 'Clipboard   Right click              Paste' },
  { label = 'Clipboard   Ctrl+Shift+V             Paste' },
  { label = 'Clipboard   Shift+Insert             Paste' },
  { label = 'Appearance  Ctrl+Shift+B             Background Inspect' },
  { label = 'Help        Ctrl+Shift+?             This keybinding sheet' },
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
