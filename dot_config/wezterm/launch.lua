local M = {}

local msys2_root = 'C:\\msys64'

local function windows_paths()
  local username = assert(os.getenv 'USERNAME', 'USERNAME is required on Windows')
  local home = msys2_root .. '\\home\\' .. username

  return {
    config = home .. '\\.config',
    data = home .. '\\.local\\share',
    state = home .. '\\.local\\state',
    cache = home .. '\\.cache',
  }
end

local function windows_native_tool_environment()
  local paths = windows_paths()

  return {
    XDG_CONFIG_HOME = paths.config,
    XDG_DATA_HOME = paths.data,
    XDG_STATE_HOME = paths.state,
    XDG_CACHE_HOME = paths.cache,
    MISE_CONFIG_DIR = paths.config .. '\\mise',
    MISE_DATA_DIR = paths.data .. '\\mise',
    MISE_STATE_DIR = paths.state .. '\\mise',
    MISE_CACHE_DIR = paths.cache .. '\\mise',
    MISE_TMP_DIR = paths.cache .. '\\mise\\tmp',
    AUBE_CACHE_DIR = paths.cache .. '\\aube',
    AUBE_STORE_DIR = paths.data .. '\\aube\\store',
  }
end

local function windows_fish_args(include_environment)
  local args = {}

  if include_environment then
    table.insert(args, msys2_root .. '\\usr\\bin\\env.exe')
    table.insert(args, 'MSYSTEM=UCRT64')
  end

  table.insert(args, msys2_root .. '\\usr\\bin\\fish.exe')
  table.insert(args, '--login')
  table.insert(args, '-i')

  return args
end

local function macos_fish_args(target)
  if target == 'aarch64-apple-darwin' then
    return { '/opt/homebrew/bin/fish', '--login', '-i' }
  end

  return { '/usr/local/bin/fish', '--login', '-i' }
end

function M.apply(config, wezterm)
  local target = wezterm.target_triple

  if target:find('windows') then
    config.default_prog = windows_fish_args(true)
    config.mux_enable_ssh_agent = false
    config.launch_menu = {
      {
        label = 'MSYS2 UCRT64 Fish',
        args = windows_fish_args(false),
        set_environment_variables = { MSYSTEM = 'UCRT64' },
      },
      {
        label = 'PowerShell',
        args = { 'pwsh.exe' },
        set_environment_variables = windows_native_tool_environment(),
      },
      {
        label = 'Windows PowerShell',
        args = { 'powershell.exe' },
        set_environment_variables = windows_native_tool_environment(),
      },
      {
        label = 'Command Prompt',
        args = { 'cmd.exe' },
        set_environment_variables = windows_native_tool_environment(),
      },
    }
  elseif target:find('apple') then
    local fish_args = macos_fish_args(target)

    config.default_prog = fish_args
    config.launch_menu = {
      {
        label = 'Fish',
        args = fish_args,
      },
      {
        label = 'Zsh',
        args = { '/bin/zsh', '-l' },
      },
    }
  elseif target:find('linux') then
    config.default_prog = { '/usr/bin/fish', '--login', '-i' }
    config.launch_menu = {
      {
        label = 'Fish',
        args = { '/usr/bin/fish', '--login', '-i' },
      },
      {
        label = 'Default shell',
        args = { os.getenv 'SHELL' or '/bin/sh', '-l' },
      },
    }
  end
end

return M
