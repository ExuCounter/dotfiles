require "setup/plugins"
require "setup/treesitter"
require "setup/configuration"
require "setup/bufferline"
require "setup/keymaps"
require "setup/git"
-- require("setup/marks")
require "setup/nvimtree"
require "setup/fzf"
require "setup/moves"
-- require("setup/lsp/mason")
require "setup/lsp/cmp"
require "setup/lsp/lspconfig"
require "setup/formatter"
require "setup/lualine"
require "setup/hop"

local numb = require "numb"
local focus = require "focus"
local colorizer = require "colorizer"
local diffconflictparts = require "diff-conflict-parts"

diffconflictparts.setup()

colorizer.setup()
numb.setup()
focus.setup {
  width = 105,
  excluded_filetypes = { "dbout" },
  signcolumn = false,
}

require("indent_blankline").setup {
  char_list = { "¦", "│", "│", "│", "│", "│", "│", "│" },
  show_foldtext = true,
  show_trailing_blankline_indent = false,
  show_first_indent_level = false,
  -- show_current_context = true,
  show_current_context_start = true,
  filetype_exclude = {
    "help",
    "terminal",
    "lazy",
    "lspinfo",
    "fzf",
    "mason",
    "",
  },
}

require("better_escape").setup {
  mapping = { "jj" },
}

require("close_buffers").setup {
  preserve_window_layout = { "this" },
  next_buffer_cmd = function(windows)
    require("bufferline").cycle(1)
    local bufnr = vim.api.nvim_get_current_buf()
    for _, window in ipairs(windows) do
      vim.api.nvim_win_set_buf(window, bufnr)
    end
  end,
}
require("trouble").setup {}

vim.api.nvim_command "Dotenv ~/Desktop/projects/own/dotfiles"

vim.opt.scroll = 12
