local M = {}

function M.apply(config, wezterm)
  local target = wezterm.target_triple

  if target:find('windows') then
    config.default_prog = {
      'C:\\msys64\\usr\\bin\\fish.exe',
      '--login',
      '-i',
    }

    config.set_environment_variables = {
      MSYSTEM = 'UCRT64',
    }

    config.mux_enable_ssh_agent = false
  elseif target == 'aarch64-apple-darwin' then
    config.default_prog = { '/opt/homebrew/bin/fish', '--login', '-i' }
  elseif target == 'x86_64-apple-darwin' then
    config.default_prog = { '/usr/local/bin/fish', '--login', '-i' }
  elseif target:find('linux') then
    config.default_prog = { '/usr/bin/fish', '--login', '-i' }
  end
end

return M
