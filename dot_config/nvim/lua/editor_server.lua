local M = {}

local registrations = {}

local function git_root(path)
    if not path or path == "" then
        return nil
    end

    return vim.fs.root(path, ".git")
end

local function git_dir(root)
    local marker = vim.fs.joinpath(root, ".git")
    local stat = vim.uv.fs_stat(marker)

    if not stat then
        return nil
    end

    if stat.type == "directory" then
        return marker
    end

    if stat.type ~= "file" then
        return nil
    end

    local lines = vim.fn.readfile(marker, "", 1)
    local line = lines[1]

    if not line then
        return nil
    end

    local path = line:match("^gitdir:%s*(.+)$")

    if not path then
        return nil
    end

    if not vim.fs.is_absolute(path) then
        path = vim.fs.joinpath(root, path)
    end

    return vim.fs.normalize(path)
end

local function registration_path(path)
    local root = git_root(path)

    if not root then
        return nil
    end

    local directory = git_dir(root)

    if not directory then
        return nil
    end

    return vim.fs.joinpath(directory, "nvim-server")
end

local function register(path)
    local server = vim.v.servername

    if not server or server == "" then
        return
    end

    local target = registration_path(path)

    if not target then
        return
    end

    local ok = pcall(vim.fn.writefile, { server }, target)

    if not ok then
        return
    end

    registrations[target] = server
end

local function register_current_context()
    local buffer = vim.api.nvim_get_current_buf()
    local name = vim.api.nvim_buf_get_name(buffer)

    if name ~= "" and vim.bo[buffer].buftype == "" then
        register(vim.fs.dirname(name))
        return
    end

    register(vim.fn.getcwd())
end

local function unregister_owned_servers()
    for path, server in pairs(registrations) do
        local lines = vim.fn.filereadable(path) == 1
            and vim.fn.readfile(path, "", 1)
            or {}

        if lines[1] == server then
            pcall(vim.fn.delete, path)
        end
    end
end

function M.setup()
    local group = vim.api.nvim_create_augroup(
        "external_editor_server",
        { clear = true }
    )

    vim.api.nvim_create_autocmd({
        "VimEnter",
        "BufEnter",
        "DirChanged",
        "FocusGained",
    }, {
        group = group,
        callback = register_current_context,
    })

    vim.api.nvim_create_autocmd("VimLeavePre", {
        group = group,
        callback = unregister_owned_servers,
    })
end

return M
