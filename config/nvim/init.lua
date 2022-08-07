require("config/plugins")
require("config/treesitter")
require("config/configuration")
require("config/buffer-line")
require("config/keymaps")
require("config/git")
require("config/mark")
require("config/nvimtree")
require("config/fzf")
require("config/moves")
require("config/windows")
require("config/lsp/mason")

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

require("indent_blankline").setup {
    -- for example, context is off by default, use this to turn it on
    show_current_context = true
    -- show_current_context_start = true
}

vim.g.indent_blankline_char = "¦"

vim.cmd(
    [[
hi BufferLineFill ctermbg=254 guibg=#eee8d5
highlight IndentBlanklineChar guifg=#8b9898 gui=nocombine guibg=NONE
]]
)
