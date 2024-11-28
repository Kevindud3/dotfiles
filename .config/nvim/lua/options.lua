vim.g.mapleader = " "
vim.g.maplocalleader = ","
vim.opt.clipboard = "unnamedplus"
vim.opt.ignorecase = true
vim.opt.inccommand = "split"
vim.opt.number = true
vim.opt.relativenumber = true
vim.opt.scrolloff = 999
vim.opt.shiftwidth = 4
vim.opt.spell = true
vim.opt.spelllang = { "en_us", "pt_br" }
vim.opt.splitbelow = true
vim.opt.splitright = true
vim.opt.tabstop = 4
vim.opt.termguicolors = true
vim.opt.virtualedit = "block"
vim.wo.foldlevel = 99
vim.filetype.add({
  pattern = { [".*/hypr/.*%.conf"] = "hyprlang" },
})
vim.wo.conceallevel = 2
