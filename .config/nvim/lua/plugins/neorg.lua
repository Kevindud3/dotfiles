return {
	{
		"nvim-neorg/neorg",
		lazy = false,
		version = "*",
		config = function()
			require("neorg").setup {
				load = {
					["core.latex.renderer"] = {
						config = {
							--conceal = false,
							--scale = 2,
							--render_on_enter = true,
						},
					},
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
								undergrad = "~/Notebook/"
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
	}
}
