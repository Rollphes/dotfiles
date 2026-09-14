local conform = require("conform")

local JS_FILETYPES = {
    "javascript",
    "javascriptreact",
    "typescript",
    "typescriptreact",
}

local function project_root(start)
    return vim.fs.root(start, {
        ".git",
        "package.json",
        "pnpm-workspace.yaml",
        "yarn.lock",
    })
end

local function find_upward(start, names)
    local root = project_root(start)

    local found = vim.fs.find(names, {
        path = start,
        upward = true,
        stop = root and vim.fs.dirname(root) or vim.uv.os_homedir(),
        limit = 1,
    })

    return found[1]
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

local function nearest_package(start)
    local path = find_upward(start, { "package.json" })

    if not path then
        return nil
    end

    return read_json(path)
end

local function js_formatters(bufnr)
    local filename = vim.api.nvim_buf_get_name(bufnr)

    if filename == "" then
        return {}
    end

    local start = vim.fs.dirname(filename)
    local package = nearest_package(start)

    -- Biome
    if find_upward(start, {
            "biome.json",
            "biome.jsonc",
        }) then
        return { "biome" }
    end

    -- Oxc / Oxfmt
    if find_upward(start, {
            ".oxfmtrc.json",
            ".oxfmtrc.jsonc",
        })
        or has_dependency(package, "oxfmt")
    then
        return { "oxfmt" }
    end

    -- ESLint + Prettier integration
    local eslint_config = find_upward(start, {
        "eslint.config.js",
        "eslint.config.mjs",
        "eslint.config.cjs",
        "eslint.config.ts",
        ".eslintrc",
        ".eslintrc.js",
        ".eslintrc.cjs",
        ".eslintrc.json",
        ".eslintrc.yml",
        ".eslintrc.yaml",
    })

    if eslint_config
        and has_dependency(package, "eslint-plugin-prettier")
    then
        return {
            "eslint_d",
            "eslint",
            stop_after_first = true,
        }
    end

    -- Standalone Prettier
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
        })
        or (package and package.prettier ~= nil)
    then
        return {
            "prettier",
            stop_after_first = true,
        }
    end

    return {}
end

local formatters_by_ft = {
    lua = { "stylua" },
    rust = { "rustfmt" },
    go = { "gofmt" },
    fish = { "fish_indent" },
}

for _, ft in ipairs(JS_FILETYPES) do
    formatters_by_ft[ft] = js_formatters
end

conform.setup({
    formatters_by_ft = formatters_by_ft,

    format_on_save = {
        timeout_ms = 1000,
        lsp_format = "fallback",
    },
})
