local wezterm = require 'wezterm'

local config = wezterm.config_builder()

require('launch').apply(config, wezterm)
require('appearance').apply(config, wezterm)

return config
