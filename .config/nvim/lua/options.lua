vim.g.mapleader = " "
--vim.opt.wrap = false
vim.g.maplocalleader = ","
vim.opt.clipboard = "unnamedplus"
--vim.opt.textwidth = 80
--vim.opt.formatoptions:append("t")
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
vim.api.nvim_set_keymap('i', '<C-l>', '<c-g>u<Esc>[s1z=`]a<c-g>u', { noremap = true, silent = true })
vim.g.livepreview_previewer = 'zathura'

-- Automatically save the file when entering normal mode (only for .norg files)
vim.api.nvim_create_autocmd("InsertLeave", {
  pattern = "*.norg",          -- Only apply to .norg files
  callback = function()
    vim.cmd("silent! write")   -- Save the file silently
  end
})

