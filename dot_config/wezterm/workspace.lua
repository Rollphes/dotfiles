local M = {}

function M.actions(wezterm)
  local act = wezterm.action

  return {
    switch = act.ShowLauncherArgs {
      flags = 'FUZZY|WORKSPACES',
      title = 'Workspaces',
    },
    create = act.PromptInputLine {
      description = 'Enter name for new workspace',
      action = wezterm.action_callback(function(window, pane, line)
        if line and line ~= '' then
          window:perform_action(act.SwitchToWorkspace { name = line }, pane)
        end
      end),
    },
    rename = act.PromptInputLine {
      description = 'Enter new name for current workspace',
      action = wezterm.action_callback(function(window, pane, line)
        if line and line ~= '' then
          wezterm.mux.rename_workspace(window:active_workspace(), line)
        end
      end),
    },
  }
end

return M
