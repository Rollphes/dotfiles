local help = require 'help'

local M = {}

function M.setup(wezterm, workspace)
  local act = wezterm.action

  wezterm.on('augment-command-palette', function()
    return {
      {
        brief = 'Workspace: Switch',
        doc = 'Show the workspace picker',
        icon = 'md_folder_swap',
        action = workspace.switch,
      },
      {
        brief = 'Workspace: Create',
        doc = 'Create and switch to a new workspace',
        icon = 'md_create_new_folder',
        action = workspace.create,
      },
      {
        brief = 'Workspace: Rename',
        doc = 'Rename the current workspace',
        icon = 'md_drive_file_rename_outline',
        action = workspace.rename,
      },
      {
        brief = 'Help: Keybindings',
        doc = 'Show the WezTerm keybinding sheet',
        icon = 'md_keyboard',
        action = help.action(wezterm),
      },
    }
  end)

  wezterm.on(
    'new-tab-button-click',
    function(window, pane, button)
      if button == 'Right' then
        window:perform_action(
          act.ShowLauncherArgs {
            flags = 'LAUNCH_MENU_ITEMS|DOMAINS',
          },
          pane
        )

        return false
      end
    end
  )
end

return M
