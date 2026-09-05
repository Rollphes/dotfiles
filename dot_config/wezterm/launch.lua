local M = {}

function M.apply(config, wezterm)
  if wezterm.target_triple:find('windows') then
    config.default_prog = {
      'C:\\msys64\\usr\\bin\\fish.exe',
      '--login',
      '-i',
    }

    config.set_environment_variables = {
      MSYSTEM = 'UCRT64',
    }

    config.mux_enable_ssh_agent = false
  end
end

return M
