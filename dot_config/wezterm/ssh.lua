local M = {}

local msys2_root = 'C:\\msys64'

local function ssh_config_path(wezterm)
  local target = wezterm.target_triple

  if target:find 'windows' then
    local username = assert(
      os.getenv 'USERNAME',
      'USERNAME is required on Windows'
    )

    return msys2_root
      .. '\\home\\'
      .. username
      .. '\\.ssh\\config'
  end

  local home = assert(
    os.getenv 'HOME',
    'HOME is required'
  )

  return home .. '/.ssh/config'
end

local function remote_address(host, ssh)
  local hostname = ssh.hostname or host
  local port = ssh.port

  if port and port ~= '22' then
    return hostname .. ':' .. port
  end

  return hostname
end

function M.apply(config, wezterm)
  local hosts = wezterm.enumerate_ssh_hosts(
    ssh_config_path(wezterm)
  )

  local domains = {}

  for host, ssh in pairs(hosts) do
    local domain = {
      name = 'SSH:' .. host,
      remote_address = remote_address(host, ssh),
      username = ssh.user,
      multiplexing = 'None',
    }

    if ssh.identityfile then
      domain.ssh_option = {
        identityfile = ssh.identityfile,
      }
    end

    table.insert(domains, domain)
  end

  table.sort(domains, function(a, b)
    return a.name < b.name
  end)

  config.ssh_domains = domains
end

return M
