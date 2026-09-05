local wezterm = require 'wezterm'

local config = wezterm.config_builder()

require('launch').apply(config, wezterm)
require('appearance').apply(config, wezterm)
require('input').apply(config, wezterm)

local workspace = require('workspace').actions(wezterm)
require('ui').setup(wezterm, workspace)
require('status').setup(wezterm)

return config
