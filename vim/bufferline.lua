vim.opt.termguicolors = true

require("bufferline").setup({
	options = {
		mode = "buffers",
		diagnostics = "none",
		show_buffer_close_icons = false,
		show_close_icon = false,
		indicator_icon = "",
		offsets = {
			{
				filetype = "NvimTree",
				text = "",
				highlight = "Directory",
				text_align = "left",
			},
		},
	},
})

