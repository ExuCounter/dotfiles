require("setup/plugins")
require("setup/treesitter")
require("setup/configuration")
require("setup/bufferline")
require("setup/keymaps")
require("setup/git")
require("setup/marks")
require("setup/nvimtree")
require("setup/fzf")
require("setup/moves")
require("setup/lualine")
require("setup/windows")
require("setup/lsp/mason")
require("setup/lsp/cmp")
require("setup/lsp/lspconfig")
require("setup/formatter")

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

vim.g.indent_blankline_char_list = {"¦", "│", "│", "│", "│", "│", "│", "│"}
vim.g.indent_blankline_show_foldtext = true

vim.cmd(
    [[
hi BufferLineFill ctermbg=254 guibg=#eee8d5
highlight IndentBlanklineChar guifg=#8b9898 gui=nocombine guibg=NONE
]]
)
