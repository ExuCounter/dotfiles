require("plugins")
require("treesitter")
require("configuration")
require("buffer-line")
require("keymaps")
require("git")
require("marks")
require("nvimtree")
require("fzf")
require("moves")
require("windows")
require("/lsp/mason")

local numb = require("numb")
local focus = require("focus")
local neoscroll = require("neoscroll")

numb.setup()
focus.setup(
    {
        width = 105
    }
)
neoscroll.setup(
    {
        hide_cursor = false,
        mappings = {"<C-u>", "<C-d>", "zt", "zz", "zb"}
    }
)
