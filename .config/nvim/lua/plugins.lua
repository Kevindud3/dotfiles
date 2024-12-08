local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not (vim.uv or vim.loop).fs_stat(lazypath) then
	local lazyrepo = "https://github.com/folke/lazy.nvim.git"
	local out = vim.fn.system({ "git", "clone", "--filter=blob:none", "--branch=stable", lazyrepo, lazypath })
	if vim.v.shell_error ~= 0 then
		vim.api.nvim_echo({
			{ "Failed to clone lazy.nvim:\n", "ErrorMsg" },
			{ out, "WarningMsg" },
			{ "\nPress any key to exit..." },
		}, true, {})
		vim.fn.getchar()
		os.exit(1)
	end
end
vim.opt.rtp:prepend(lazypath)
vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1
require("lazy").setup({
	spec = {
		{
			"rebelot/kanagawa.nvim",
			config = function()
				vim.cmd("colorscheme kanagawa")
			end,
		},
		{
			"nvim-treesitter/nvim-treesitter",
			config = function()
				require ("nvim-treesitter.configs").setup ({
					ensure_installed = { "c", "lua", "vim", "vimdoc", "query" },
					auto_install = true,
					highlight = {
						enable = true },
						incremental_selection = {
							enable = true,
							keymaps = {
								init_selection = "<Leader>ss",
								node_incremental = "<Leader>si",
								scope_incremental = "<Leader>sc",
								node_decremental = "<Leader>sd",
							},
						},
					})
				end
			},
			{
				"nvim-neorg/neorg",
				lazy = false,
				version = "*",
				config = function()
					require("neorg").setup {
						load = {
							["core.defaults"] = {},
							["core.integrations.telescope"] = {},
							["core.export"] = {},
							["core.integrations.coq_nvim"] = {},
							["core.concealer"] = {
								config = {
									icon_preset = "diamond",
								},
							},
							["core.dirman"] = {
								config = {
									workspaces = {
										notes = "~/Documents/Notes",
									},
									default_workspace = "notes",
								},
							},
							["core.completion"] = {
								config = {
									engine = "coq_nvim",
								},
							},
							["core.summary"] = {
								config = {
									strategy = "default",
								}
							},
						},
					}
				end,
			},
			{
				"norcalli/nvim-colorizer.lua",
				config = function()
					require("colorizer").setup({ "*" })
				end,
			},
			{
				"3rd/image.nvim",
				opts = {},
			},
			{
				"HakonHarnes/img-clip.nvim",
				config = function()
					require("img-clip").setup({
						event = "VeryLazy",
						opts = {
							-- add options here
							-- or leave it empty to use the default settings
						},
						keys = {
							-- suggested keymap
							{ "<leader>p", "<cmd>PasteImage<cr>", desc = "Paste image from system clipboard" },
						},
					})
				end,
			},
			{
				"dhruvasagar/vim-table-mode",
			},
			{
				"nvim-lualine/lualine.nvim",
				dependencies = { "nvim-tree/nvim-web-devicons" },
				config = function()
					require("lualine").setup({
						options = {
							icons_enabled = true,
							theme = "auto",
							component_separators = { left = "", right = '' },
							section_separators = { left = "", right = '' },
							disabled_filetypes = {
								statusline = {},
								winbar = {},
							},
							ignore_focus = {},
							always_divide_middle = true,
							always_show_tabline = true,
							globalstatus = false,
							refresh = {
								statusline = 100,
								tabline = 100,
								winbar = 100,
							}
						},
						sections = {
							lualine_a = {"mode"},
							lualine_b = {"branch", 'diff', 'diagnostics'},
							lualine_c = {"filetype", 'filename'},
							lualine_x = {"encoding", 'fileformat'},
							lualine_y = {"progress"},
							lualine_z = {"location"}
						},
						inactive_sections = {
							lualine_a = {},
							lualine_b = {},
							lualine_c = {"filename"},
							lualine_x = {"location"},
							lualine_y = {},
							lualine_z = {}
						},
						tabline = {},
						winbar = {},
						inactive_winbar = {},
						extensions = {}
					})
				end
			},
			{
				"nvim-telescope/telescope.nvim",
				tag = "0.1.8",
				dependencies = { "nvim-lua/plenary.nvim" },
				config = function()
					require("telescope").setup({
						defaults = {
						}
					})
				end
			},
			{
				"nvim-neorg/neorg-telescope"
			},
			{
				"neovim/nvim-lspconfig",
				lazy = false,
				dependencies = {
					{ "ms-jpq/coq_nvim", branch = "coq" },
					{ "ms-jpq/coq.artifacts", branch = "artifacts" },
					-- lua & third party sources -- See https://github.com/ms-jpq/coq.thirdparty
					-- Need to **configure separately**
					{ "ms-jpq/coq.thirdparty", branch = "3p" }
				},
				init = function()
					vim.g.coq_settings = {
						auto_start = true,
					}
				end,
				config = function()
					local lsp = require "lspconfig"
					local coq = require "coq"
					-- Clangd (C/C++/Objective-C language server)
					lsp.clangd.setup(coq.lsp_ensure_capabilities({
						on_attach = function(client, bufnr)
							-- Custom on_attach logic for clangd
						end,
						flags = {
							debounce_text_changes = 150,
						},
					}))

					-- CSS-LSP (CSS Language Server)
					lsp.cssls.setup(coq.lsp_ensure_capabilities({
						on_attach = function(client, bufnr)
							-- Custom on_attach logic for css-lsp
						end,
						flags = {
							debounce_text_changes = 150,
						},
					}))

					-- Harper-LS (Harper Language Server)
					lsp.harper_ls.setup(coq.lsp_ensure_capabilities({
						on_attach = function(client, bufnr)
							-- Custom on_attach logic for harper-ls
						end,
						flags = {
							debounce_text_changes = 150,
						},
					}))

					-- Lua Language Server (sumneko/lua-language-server)
					lsp.lua_ls.setup(coq.lsp_ensure_capabilities({
						on_attach = function(client, bufnr)
							-- Custom on_attach logic for lua-language-server
						end,
						flags = {
							debounce_text_changes = 150,
						},
					}))
				end,
			},							{
				"williamboman/mason.nvim",
				config = function()
					require("mason").setup()
				end,
			},
			{
				"williamboman/mason-lspconfig",
				dependencies = {"mason.nvim"},
				config = function()
					require("mason-lspconfig").setup()
					require("mason-lspconfig").setup_handlers {
						function (server_name)
							require("lspconfig")[server_name].setup {}
						end,
					}
				end,
			},
			{
				"nvim-tree/nvim-tree.lua",
				version = "*",
				lazy = false,
				dependencies = {
					"nvim-tree/nvim-web-devicons",
				},
				config = function()
					require("nvim-tree").setup {}
				end,
			},
			{
				"startup-nvim/startup.nvim",
				dependencies = { "nvim-telescope/telescope.nvim", "nvim-lua/plenary.nvim", "nvim-telescope/telescope-file-browser.nvim" },
				config = function()
					require "startup".setup()
				end
			},
			{
				"NStefan002/speedtyper.nvim",
				cmd = "Speedtyper",
				opts = {
					-- your config
				}
			},
			{
				"ThePrimeagen/vim-be-good"
			},
			{
				"rcarriga/nvim-notify"
			},
			{
				"stevearc/dressing.nvim",
				opts = {},
			},
			{
				"jbyuki/nabla.nvim",
				keys = {
					{ "<localleader>p", function() require("nabla").popup() end, desc = "Notation", },
				},
			},

			{
				"folke/which-key.nvim",
				event = "VeryLazy",
				opts = {
					-- your configuration comes here
					-- or leave it empty to use the default settings
					-- refer to the configuration section below
				},
				keys = {
					{
						"<leader>?",
						function()
							require("which-key").show({ global = false })
						end,
						desc = "Buffer Local Keymaps (which-key)",
					},
				},
			},
		}
	})
	vim.notify = require("notify")
