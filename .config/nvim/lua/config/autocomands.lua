-- This will map the desired command to <C-l> in Normal mode.
vim.keymap.set('i', '<C-l>', function()
  -- Start the sequence: jump to previous spelling mistake
  vim.cmd('normal! [s')
  -- Pick the first suggestion
  vim.cmd('normal! 1z=')
  -- Jump back
  vim.cmd('normal! A')
end)
-- Automatically save the file when entering normal mode (only for .norg files)
vim.api.nvim_create_autocmd("InsertLeave", {
  pattern = "*.norg",          -- Only apply to .norg files
  callback = function()
    vim.cmd("silent! write")   -- Save the file silently
  end
})

-- Hyprlang LSP
vim.api.nvim_create_autocmd({'BufEnter', 'BufWinEnter'}, {
		pattern = {"*.hl", "hypr*.conf"},
		callback = function(event)
				print(string.format("starting hyprls for %s", vim.inspect(event)))
				vim.lsp.start {
						name = "hyprlang",
						cmd = {"hyprls"},
						root_dir = vim.fn.getcwd(),
				}
		end
})

vim.filetype.add({
  pattern = { [".*/hypr/.*%.conf"] = "hyprlang" },
})
