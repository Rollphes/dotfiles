local conform = require("conform")


-- ------------------------------------------------------------
-- Project helpers
-- ------------------------------------------------------------

local function project_boundary(start)
    return vim.fs.root(start, ".git")
end

local function find_upward(start, names)
    local root = project_boundary(start)

    return vim.fs.find(names, {
        path = start,
        upward = true,
        stop = root and vim.fs.dirname(root) or vim.uv.os_homedir(),
        limit = 1,
    })[1]
end

local function read_json(path)
    if not path then
        return nil
    end

    local ok, lines = pcall(vim.fn.readfile, path)
    if not ok then
        return nil
    end

    local ok_decode, value = pcall(
        vim.json.decode,
        table.concat(lines, "\n")
    )

    if not ok_decode then
        return nil
    end

    return value
end

local function file_contains(path, pattern)
    if not path then
        return false
    end

    local ok, lines = pcall(vim.fn.readfile, path)
    if not ok then
        return false
    end

    return table.concat(lines, "\n"):match(pattern) ~= nil
end

local function has_dependency(package, name)
    if not package then
        return false
    end

    local fields = {
        "dependencies",
        "devDependencies",
        "peerDependencies",
        "optionalDependencies",
    }

    for _, field in ipairs(fields) do
        if package[field] and package[field][name] ~= nil then
            return true
        end
    end

    return false
end

local function has_dependency_upward(start, name)
    local root = project_boundary(start)
    local dir = start

    while dir do
        local package_path = vim.fs.joinpath(dir, "package.json")

        if vim.fn.filereadable(package_path) == 1 then
            local package = read_json(package_path)

            if has_dependency(package, name) then
                return true
            end
        end

        if root and dir == root then
            break
        end

        local parent = vim.fs.dirname(dir)

        if not parent or parent == dir then
            break
        end

        if not root and parent == vim.uv.os_homedir() then
            break
        end

        dir = parent
    end

    return false
end


-- ------------------------------------------------------------
-- JavaScript / TypeScript
-- ------------------------------------------------------------

local JS_FILETYPES = {
    "javascript",
    "javascriptreact",
    "typescript",
    "typescriptreact",
}

local function js_formatters(bufnr)
    local filename = vim.api.nvim_buf_get_name(bufnr)

    if filename == "" then
        return {}
    end

    local start = vim.fs.dirname(filename)

    -- Biome project
    if find_upward(start, {
            "biome.json",
            "biome.jsonc",
        }) then
        return { "biome" }
    end

    -- Oxc / Oxfmt project
    if find_upward(start, {
            ".oxfmtrc.json",
            ".oxfmtrc.jsonc",
            "oxfmt.config.ts",
        })
        or has_dependency_upward(start, "oxfmt")
    then
        return { "oxfmt" }
    end

    -- ESLint owns formatting only when Prettier is explicitly
    -- integrated into ESLint.
    local eslint_config = find_upward(start, {
        "eslint.config.js",
        "eslint.config.mjs",
        "eslint.config.cjs",
        "eslint.config.ts",
        "eslint.config.mts",
        "eslint.config.cts",
        ".eslintrc",
        ".eslintrc.js",
        ".eslintrc.cjs",
        ".eslintrc.json",
        ".eslintrc.yml",
        ".eslintrc.yaml",
    })

    if eslint_config
        and has_dependency_upward(
            vim.fs.dirname(eslint_config),
            "eslint-plugin-prettier"
        )
    then
        return { "eslint" }
    end

    -- Standalone Prettier project
    if find_upward(start, {
            ".prettierrc",
            ".prettierrc.json",
            ".prettierrc.json5",
            ".prettierrc.yml",
            ".prettierrc.yaml",
            ".prettierrc.js",
            ".prettierrc.cjs",
            ".prettierrc.mjs",
            ".prettierrc.toml",
            "prettier.config.js",
            "prettier.config.cjs",
            "prettier.config.mjs",
            "prettier.config.ts",
        }) then
        return { "prettier" }
    end

    -- package.json can itself contain the Prettier configuration.
    local package_path = find_upward(start, {
        "package.json",
    })

    local package = read_json(package_path)

    if package and package.prettier ~= nil then
        return { "prettier" }
    end

    return {}
end


-- ------------------------------------------------------------
-- Python
-- ------------------------------------------------------------

local function python_formatters(bufnr)
    local filename = vim.api.nvim_buf_get_name(bufnr)

    if filename == "" then
        return {}
    end

    local start = vim.fs.dirname(filename)

    if find_upward(start, {
            "ruff.toml",
            ".ruff.toml",
        }) then
        return { "ruff_format" }
    end

    local pyproject = find_upward(start, {
        "pyproject.toml",
    })

    if pyproject then
        if file_contains(pyproject, "%[tool%.ruff[%].]") then
            return { "ruff_format" }
        end

        if file_contains(pyproject, "%[tool%.black%]") then
            return { "black" }
        end
    end

    return {}
end


-- ------------------------------------------------------------
-- Formatter map
-- ------------------------------------------------------------

local formatters_by_ft = {
    lua = { "stylua" },

    rust = { "rustfmt" },

    go = { "gofmt" },

    python = python_formatters,

    fish = { "fish_indent" },
}

for _, filetype in ipairs(JS_FILETYPES) do
    formatters_by_ft[filetype] = js_formatters
end


-- ------------------------------------------------------------
-- Setup
-- ------------------------------------------------------------

conform.setup({
    formatters_by_ft = formatters_by_ft,

    format_on_save = {
        timeout_ms = 1000,
        lsp_format = "fallback",
    },
})
