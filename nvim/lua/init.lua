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
local diffconflictparts = require "diff_conflict_parts"

diffconflictparts.setup {
  direction = "vertical",
}

colorizer.setup()
numb.setup()
-- focus.setup {
--   width = 45,
--   excluded_filetypes = { "dbout" },
--   signcolumn = false,
-- }

require("ibl").setup {
  indent = { char = { "¦", "│", "│", "│", "│", "│", "│", "│" } },
  exclude = {
    filetypes = {
      "help",
      "terminal",
      "lazy",
      "lspinfo",
      "fzf",
      "mason",
      "",
    },
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

-- vim.api.nvim_command "Dotenv ~/Desktop/projects/own/dotfiles"
