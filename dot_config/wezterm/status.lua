local M = {}

local function normalize_path(path)
  if not path or path == '' then
    return nil
  end

  local normalized = path:gsub('\\', '/'):gsub('/+$', '')
  local drive, rest = normalized:match '^/?([A-Za-z]):/(.*)$'

  if drive then
    return '/' .. drive:lower() .. '/' .. rest
  end

  return normalized
end

local function split_path(path)
  local parts = {}

  for part in path:gmatch '[^/]+' do
    table.insert(parts, part)
  end

  return parts
end

function M.format_path(path, homes, case_insensitive)
  local normalized = normalize_path(path)

  if not normalized then
    return nil
  end

  local comparable = case_insensitive and normalized:lower() or normalized
  local display = normalized

  for _, home in ipairs(homes) do
    local normalized_home = normalize_path(home)

    if normalized_home then
      local comparable_home = normalized_home
      if case_insensitive then
        comparable_home = normalized_home:lower()
      end

      if comparable == comparable_home then
        display = '~'
        break
      end

      if comparable:sub(1, #comparable_home + 1) == comparable_home .. '/' then
        display = '~' .. normalized:sub(#normalized_home + 1)
        break
      end
    end
  end

  if display == '~' then
    return display
  end

  local path_for_split = display:gsub('^~/', '')
  local parts = split_path(path_for_split)

  if #parts > 3 then
    return '.../' .. table.concat(parts, '/', #parts - 2)
  end

  return display
end

local function home_paths(wezterm)
  local homes = {}

  local function add(path)
    if path and path ~= '' then
      table.insert(homes, path)
    end
  end

  add(os.getenv 'HOME')
  add(wezterm.home_dir)

  if wezterm.target_triple:find('windows') then
    add(os.getenv 'USERPROFILE')

    local username = os.getenv 'USERNAME'
    if username and username ~= '' then
      add('/home/' .. username)
    end
  end

  return homes
end

function M.setup(wezterm)
  local homes = home_paths(wezterm)
  local is_windows = wezterm.target_triple:find('windows') ~= nil

  wezterm.on('format-window-title', function()
    return 'WezTerm'
  end)

  wezterm.on('format-tab-title', function(tab, _, _, _, _, max_width)
    local pane = tab.active_pane
    local title = pane.title
    local cwd = pane.current_working_dir

    if cwd then
      title = M.format_path(cwd.file_path or tostring(cwd), homes, is_windows)
        or title
    end

    local background = 'none'
    local foreground = '#909090'

    if tab.is_active then
      background = '#3c3c3c'
      foreground = '#c0c0c0'
    end

    title = '   '
      .. wezterm.truncate_right(title, math.max(1, max_width - 6))
      .. '   '

    return {
      { Background = { Color = background } },
      { Foreground = { Color = foreground } },
      { Text = title },
    }
  end)

  wezterm.on('update-right-status', function(window)
    window:set_right_status(
      '  WS: ' .. window:active_workspace() .. '   Help: Ctrl+Shift+?  '
    )
  end)
end

return M
