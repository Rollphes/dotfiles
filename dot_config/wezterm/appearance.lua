local M = {}

local inspect_opacity = 0.2

function M.apply(config, wezterm)
  config.font = wezterm.font_with_fallback {
    '0xProto Nerd Font',
    'UDEV Gothic 35JPDOC',
    'monospace',
  }
  config.font_size = 10.0

  local target = wezterm.target_triple

  if target:find('windows') then
    config.window_background_opacity = 0.6
    config.win32_system_backdrop = 'Acrylic'
  elseif target:find('apple') then
    config.window_background_opacity = 0.85
    config.macos_window_background_blur = 20
  end

  config.inactive_pane_hsb = {
    saturation = 0.8,
    brightness = 0.6,
  }

  config.use_fancy_tab_bar = true
  config.hide_tab_bar_if_only_one_tab = false
  config.tab_bar_at_bottom = true
  config.tab_max_width = 32

  config.colors = {
    tab_bar = {
      background = 'none',
      inactive_tab_edge = 'none',
      new_tab = {
        bg_color = 'none',
        fg_color = '#909090',
      },
      new_tab_hover = {
        bg_color = 'none',
        fg_color = '#c0c0c0',
      },
    },
  }

  config.window_frame = {
    inactive_titlebar_bg = 'none',
    active_titlebar_bg = 'none',
  }
end

function M.background_inspect_action(wezterm)
  return wezterm.action_callback(function(window)
    local overrides = window:get_config_overrides() or {}

    if overrides.window_background_opacity == inspect_opacity then
      overrides.window_background_opacity = nil
      overrides.win32_system_backdrop = nil
      overrides.macos_window_background_blur = nil
    else
      overrides.window_background_opacity = inspect_opacity

      if wezterm.target_triple:find('windows') then
        overrides.win32_system_backdrop = 'Disable'
      elseif wezterm.target_triple:find('apple') then
        overrides.macos_window_background_blur = 0
      end
    end

    window:set_config_overrides(overrides)
  end)
end

return M
