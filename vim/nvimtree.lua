local vimp = require("vimp")

-- setup with all defaults
-- each of these are documented in `:help nvim-tree.OPTION_NAME`
require("nvim-tree").setup({ -- BEGIN_DEFAULT_OPTS
	auto_reload_on_write = true,
	disable_netrw = true,
	hijack_cursor = false,
	hijack_netrw = false,
	hijack_unnamed_buffer_when_opening = false,
	ignore_buffer_on_setup = false,
	open_on_setup = false,
	open_on_setup_file = false,
	open_on_tab = false,
	sort_by = "name",
	update_cwd = false,
	view = {
		adaptive_size = true,
		width = 40,
		height = 30,
		side = "left",
		hide_root_folder = true,
		preserve_window_proportions = false,
		number = true,
		relativenumber = false,
		signcolumn = "no",
		mappings = {
			custom_only = true,
			list = {
				{ key = "<C-t>", action = "close" },
				{ key = "t", action = "tabnew" },
				{ key = "R", action = "refresh" },
				{ key = "d", action = "remove" },
				{ key = "D", action = "trash" },
				{ key = "x", action = "cut" },
				{ key = "c", action = "copy" },
				{ key = "p", action = "paste" },
				{ key = "v", action = "vsplit" },
				{ key = "<Tab>", action = "preview" },
				{ key = "a", action = "create" },
				{ key = "i", action = "toggle_file_info" },
				{ key = "y", action = "copy_name" },
				{ key = "Y", action = "copy_path" },
				{ key = "r", action = "rename" },
				{ key = "-", action = "dir_up" },
				{ key = "=", action = "cd" },
				{ key = { "<CR>", "o", "<2-LeftMouse>" }, action = "edit" },
			},
		},
	},
	renderer = {
		indent_markers = {
			enable = false,
			icons = {
				corner = "└ ",
				edge = "│ ",
				none = "  ",
			},
		},
		icons = {
			webdev_colors = true,
		},
	},
	hijack_directories = {
		enable = true,
		auto_open = true,
	},
	update_focused_file = {
		enable = false,
		update_cwd = false,
		ignore_list = {},
	},
	ignore_ft_on_setup = {},
	system_open = {
		cmd = nil,
		args = {},
	},
	diagnostics = {
		enable = false,
		show_on_dirs = false,
		icons = {
			hint = "",
			info = "",
			warning = "",
			error = "",
		},
	},
	filters = {
		dotfiles = false,
		custom = {},
		exclude = {},
	},
	git = {
		enable = true,
		ignore = true,
		timeout = 400,
	},
	actions = {
		use_system_clipboard = true,
		change_dir = {
			enable = true,
			global = false,
			restrict_above_cwd = false,
		},
		open_file = {
			quit_on_open = true,
			resize_window = false,
			window_picker = {
				enable = true,
				chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890",
				exclude = {
					filetype = { "notify", "packer", "qf", "diff", "fugitive", "fugitiveblame" },
					buftype = { "nofile", "terminal", "help" },
				},
			},
		},
	},
	trash = {
		cmd = "trash",
		require_confirm = true,
	},
	log = {
		enable = false,
		truncate = false,
		types = {
			all = false,
			config = false,
			copy_paste = false,
			diagnostics = false,
			git = false,
			profile = false,
		},
	},
}) -- END_DEFAULT_OPTSg

vimp.nmap("<C-t>", ":NvimTreeToggle<CR>")
vimp.nnoremap("<leader>r", ":NvimTreeRefresh<CR>")
vimp.nnoremap({ "chord" }, "<leader>t", ":NvimTreeFindFile<CR>")

-- You dont need to set any of these options. These are the default ones. Only
-- the loading is important
-- require("telescope").setup({
-- 	extensions = {
-- 		fzf = {
-- 			fuzzy = true, -- false will only do exact matching
-- 			override_generic_sorter = true, -- override the generic sorter
-- 			override_file_sorter = true, -- override the file sorter
-- 			case_mode = "smart_case", -- or "ignore_case" or "respect_case"
-- 		},
-- 		media_files = {
-- 			-- filetypes whitelist
-- 			-- defaults to {"png", "jpg", "mp4", "webm", "pdf"}
-- 			filetypes = { "png", "webp", "jpg", "jpeg" },
-- 			find_cmd = "rg", -- find command (defaults to `fd`)
-- 		},
-- 	},
-- 	defaults = {
-- 		layout_strategy = "bottom_pane",
-- 		layout_config = {
-- 			height = 0.55,
-- 			preview_width = 0.4,
-- 			prompt_position = "bottom",
-- 			width = 0.95,
-- 		},
-- 	},
-- })
-- -- To get fzf loaded and working with telescope, you need to call
-- -- load_extension, somewhere after setup function:
-- require("telescope").load_extension("fzf")
-- require("telescope").load_extension("media_files")

