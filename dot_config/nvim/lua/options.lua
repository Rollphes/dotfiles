vim.opt.number = true
vim.opt.relativenumber = false
vim.opt.cursorline = true
vim.opt.cursorcolumn = false
vim.opt.signcolumn = "yes"
vim.opt.wrap = false
vim.opt.linebreak = false
vim.opt.scrolloff = 4
vim.opt.sidescrolloff = 8
vim.opt.termguicolors = true
vim.opt.background = "dark"
vim.opt.list = true
vim.opt.listchars = {
    tab = "→ ",
    lead = "·",
    trail = "·",
    nbsp = "␣",
    eol = "↲",
}

vim.opt.expandtab = true
vim.opt.tabstop = 4
vim.opt.shiftwidth = 4
vim.opt.softtabstop = 4
vim.opt.autoindent = true
vim.opt.smartindent = false
vim.opt.breakindent = false

vim.opt.ignorecase = true
vim.opt.smartcase = true
vim.opt.hlsearch = true
vim.opt.incsearch = true
vim.opt.wrapscan = true

vim.opt.splitbelow = true
vim.opt.splitright = true
vim.opt.equalalways = true

vim.opt.mouse = "a"
vim.opt.hidden = true
vim.opt.undofile = true
vim.opt.undolevels = 1000

vim.opt.backup = false
vim.opt.writebackup = true
vim.opt.swapfile = true
vim.opt.autoread = true
vim.opt.autowrite = false
vim.opt.confirm = false
vim.opt.fixendofline = true

vim.opt.completeopt = { "menu", "popup" }
vim.opt.pumheight = 0
vim.opt.pumblend = 0

vim.opt.wildmenu = true
vim.opt.wildmode = { "longest:full", "full" }
vim.opt.wildoptions = { "pum" }

vim.opt.updatetime = 4000
vim.opt.timeout = true
vim.opt.timeoutlen = 1000

vim.opt.laststatus = 2
vim.opt.showmode = true
vim.opt.cmdheight = 0
vim.opt.ruler = true
