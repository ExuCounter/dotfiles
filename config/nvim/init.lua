require("plugins")
require("configuration")
require("treesitter")
require("bufferline")
require("keymaps")
require("git")
require("marks")
require("nvimtree")
require("fzf")
require("moves")

local numb = require("numb")
local focus = require("focus")
local neoscroll = require("neoscroll")

numb.setup()
focus.setup({
	width = 105,
})
neoscroll.setup({
	hide_cursor = false,
	mappings = { "<C-u>", "<C-d>", "zt", "zz", "zb" },
})

