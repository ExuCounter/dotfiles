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
require("setup/lsp/mason")
require("setup/lsp/cmp")
require("setup/lsp/lspconfig")
require("setup/formatter")
require("setup/lualine")
require("setup/dashboard")
require("setup/utils")
require("setup/hop")

local numb = require("numb")
local focus = require("focus")
local neoscroll = require("neoscroll")

numb.setup()
focus.setup(
    {
        width = 97,
        excluded_filetypes = {"dbout"}
    }
)
neoscroll.setup(
    {
        hide_cursor = false,
        mappings = {"<C-u>", "<C-d>", "zt", "zz", "zb"}
    }
)

require("indent_blankline").setup {
    show_first_indent_level = false,
    show_current_context = true,
    show_current_context_start = true,
    use_treesitter = true,
    char_list = {"¦", "│", "│", "│", "│", "│", "│", "│"},
    show_foldtext = true
}

require("better_escape").setup {
    mapping = {"jj"}
}
