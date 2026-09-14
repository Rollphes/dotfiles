local M = {}

local terminal = {
    buffer = nil,
    height = 12,
    return_windows = {},
}

local function windows_shell()
    local required_environment = {
        "MSYSTEM",
        "USERNAME",
        "HOME",
        "USERPROFILE",
        "APPDATA",
        "LOCALAPPDATA",
        "TEMP",
        "TMP",
        "XDG_CONFIG_HOME",
        "XDG_DATA_HOME",
        "XDG_STATE_HOME",
        "XDG_CACHE_HOME",
        "MISE_CONFIG_DIR",
        "MISE_DATA_DIR",
        "MISE_STATE_DIR",
        "MISE_CACHE_DIR",
        "MISE_TMP_DIR",
    }

    local missing = {}

    for _, name in ipairs(required_environment) do
        if not vim.env[name] or vim.env[name] == "" then
            table.insert(missing, name)
        end
    end

    if #missing > 0 then
        error(
            "refusing to start MSYS2 fish with an incomplete Neovim environment: "
                .. table.concat(missing, ", ")
        )
    end

    if vim.env.MSYSTEM ~= "UCRT64" then
        error("refusing to replace the current MSYS2 authority: MSYSTEM must be UCRT64")
    end

    local msys2_root = "C:\\msys64"
    local env = msys2_root .. "\\usr\\bin\\env.exe"
    local fish = msys2_root .. "\\usr\\bin\\fish.exe"

    if vim.fn.executable(env) ~= 1 or vim.fn.executable(fish) ~= 1 then
        error("MSYS2 env.exe and fish.exe are required below C:\\msys64\\usr\\bin")
    end

    -- jobstart inherits Neovim's complete process environment. env.exe only
    -- carries forward the already-authoritative MSYSTEM value; no HOME/XDG or
    -- Windows profile variables are guessed or reconstructed here.
    return { env, "MSYSTEM=" .. vim.env.MSYSTEM, fish, "--login", "-i" }
end

local function native_fish(path)
    if vim.fn.executable(path) ~= 1 then
        error("managed fish executable not found: " .. path)
    end

    return { path, "--login", "-i" }
end

local function shell_command()
    local platform = vim.uv.os_uname()

    if platform.sysname == "Windows_NT" then
        return windows_shell()
    end

    if platform.sysname == "Darwin" then
        local apple_silicon = platform.machine == "arm64" or platform.machine == "aarch64"
        local fish = apple_silicon and "/opt/homebrew/bin/fish" or "/usr/local/bin/fish"

        return native_fish(fish)
    end

    if platform.sysname == "Linux" then
        return native_fish("/usr/bin/fish")
    end

    error("integrated terminal is not configured for " .. platform.sysname)
end

local function job_is_running(buffer)
    if not buffer or not vim.api.nvim_buf_is_valid(buffer) then
        return false
    end

    local job = vim.bo[buffer].channel

    return job > 0 and vim.fn.jobwait({ job }, 0)[1] == -1
end

local function visible_window(buffer, tabpage)
    if not buffer or not vim.api.nvim_buf_is_valid(buffer) then
        return nil
    end

    for _, window in ipairs(vim.fn.win_findbuf(buffer)) do
        if vim.api.nvim_win_get_tabpage(window) == tabpage then
            return window
        end
    end

    return nil
end

local function hide(window)
    local tabpage = vim.api.nvim_win_get_tabpage(window)
    local return_window = terminal.return_windows[tabpage]
    local restore_focus = vim.api.nvim_get_current_win() == window

    vim.api.nvim_win_close(window, true)

    if restore_focus and return_window and vim.api.nvim_win_is_valid(return_window) then
        vim.api.nvim_set_current_win(return_window)
    end
end

local function start_terminal(buffer, cwd)
    local ok, command = pcall(shell_command)

    if not ok then
        vim.notify(command, vim.log.levels.ERROR)
        return false
    end

    local job = vim.fn.jobstart(command, {
        cwd = cwd,
        term = true,
    })

    if job <= 0 then
        vim.notify("failed to start the integrated terminal", vim.log.levels.ERROR)
        return false
    end

    vim.bo[buffer].bufhidden = "hide"
    vim.bo[buffer].buflisted = false
    vim.b[buffer].stg6_integrated_terminal = true

    return true
end

local function show()
    local tabpage = vim.api.nvim_get_current_tabpage()
    local current_window = vim.api.nvim_get_current_win()
    local cwd = vim.fn.getcwd(0)

    if not job_is_running(terminal.buffer) then
        if terminal.buffer and vim.api.nvim_buf_is_valid(terminal.buffer) then
            vim.api.nvim_buf_delete(terminal.buffer, { force = true })
        end

        terminal.buffer = vim.api.nvim_create_buf(false, true)
    end

    terminal.return_windows[tabpage] = current_window
    vim.cmd("botright " .. terminal.height .. "split")

    local terminal_window = vim.api.nvim_get_current_win()
    vim.wo[terminal_window].winfixheight = true
    vim.api.nvim_win_set_buf(terminal_window, terminal.buffer)

    if not job_is_running(terminal.buffer) and not start_terminal(terminal.buffer, cwd) then
        vim.api.nvim_win_close(terminal_window, true)
        return
    end

    vim.cmd.startinsert()
end

function M.toggle()
    local tabpage = vim.api.nvim_get_current_tabpage()
    local window = visible_window(terminal.buffer, tabpage)

    if window then
        hide(window)
        return
    end

    show()
end


return M
