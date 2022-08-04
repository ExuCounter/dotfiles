local treesitter = require("nvim-treesitter.configs")

-- treesitter.setup({
-- 	ensure_installed = "all", -- one of "all", "maintained" (parsers with maintainers), or a list of languages
-- 	highlight = {
-- 		enable = false, -- false will disable the whole extensio
-- 		additional_vim_regex_highlighting = false,
-- 		use_languagetree = true,
-- 		disable = { "html" },
-- 	},
-- 	ignore_install = { "phpdoc" },
-- 	auto_install = true,
-- 	autotag = {
-- 		enable = true,
-- 	},
-- 	matchup = {
-- 		enable = true,
-- 	},
-- 	context_commentstring = {
-- 		enable = true,
-- 		enable_autocmd = false,
-- 	},
-- 	rainbow = {
-- 		enable = false,
-- 		-- disable = { "jsx", "cpp" }, list of languages you want to disable the plugin for
-- 		-- extended_mode = true, -- Also highlight non-bracket delimiters like html tags, boolean or table: lang -> boolean
-- 		max_file_lines = nil, -- Do not enable for files with more than n lines, int
-- 		colors = {
-- 			"#e5c07b",
-- 			"#dcdfe4",
-- 			"#7d8dad",
-- 			"#56b6c2",
-- 			"#98c379",
-- 			"#61afef",
-- 		}, -- table of hex strings
-- 		-- termcolors = {} -- table of colour name strings
-- 	},
-- })

vim.api.nvim_set_keymap(
	"n",
	"f",
	"<cmd>lua require'hop'.hint_char1({ direction = require'hop.hint'.HintDirection.AFTER_CURSOR, current_line_only = true })<cr>",
	{}
)
vim.api.nvim_set_keymap(
	"n",
	"F",
	"<cmd>lua require'hop'.hint_char1({ direction = require'hop.hint'.HintDirection.BEFORE_CURSOR, current_line_only = true })<cr>",
	{}
)
vim.api.nvim_set_keymap(
	"o",
	"f",
	"<cmd>lua require'hop'.hint_char1({ direction = require'hop.hint'.HintDirection.AFTER_CURSOR, current_line_only = true, inclusive_jump = true })<cr>",
	{}
)
vim.api.nvim_set_keymap(
	"o",
	"F",
	"<cmd>lua require'hop'.hint_char1({ direction = require'hop.hint'.HintDirection.BEFORE_CURSOR, current_line_only = true, inclusive_jump = true })<cr>",
	{}
)
vim.api.nvim_set_keymap(
	"",
	"t",
	"<cmd>lua require'hop'.hint_char1({ direction = require'hop.hint'.HintDirection.AFTER_CURSOR, current_line_only = true })<cr>",
	{}
)
vim.api.nvim_set_keymap(
	"",
	"T",
	"<cmd>lua require'hop'.hint_char1({ direction = require'hop.hint'.HintDirection.BEFORE_CURSOR, current_line_only = true })<cr>",
	{}
)

