local lazypath = vim.fn.stdpath "data" .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
  vim.fn.system {
    "git",
    "clone",
    "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git",
    "--branch=stable", -- latest stable release
    lazypath,
  }
end

vim.opt.rtp:prepend(lazypath)

require("lazy").setup {
  "wbthomason/packer.nvim",
  -- UI
  "lifepillar/vim-solarized8",
  "kyazdani42/nvim-tree.lua",
  -- Commentary
  "tpope/vim-commentary",
  -- Git
  "tpope/vim-fugitive",
  "itchyny/vim-gitbranch",
  "lewis6991/gitsigns.nvim",
  "rhysd/conflict-marker.vim",
  -- DB
  "tpope/vim-dadbod",
  "kristijanhusak/vim-dadbod-ui",
  -- Fzf
  { "ibhagwan/fzf-lua", branch = "main" },
  -- Windows
  "christoomey/vim-tmux-navigator",
  "simeji/winresizer",
  -- Moves
  "rhysd/accelerated-jk",
  "phaazon/hop.nvim",
  -- Syntax
  { "nvim-treesitter/nvim-treesitter" },
  { "JoosepAlviste/nvim-ts-context-commentstring", dependencies = { "nvim-treesitter/nvim-treesitter" } },
  { "windwp/nvim-ts-autotag", dependencies = { "nvim-treesitter/nvim-treesitter" } },
  -- CMP
  "hrsh7th/cmp-nvim-lsp",
  "hrsh7th/cmp-buffer",
  { "hrsh7th/cmp-cmdline", commit = "d2dfa338520c99c1f2dc6af9388de081a6e63296" },
  "hrsh7th/nvim-cmp",
  "hrsh7th/cmp-nvim-lsp-signature-help",
  "hrsh7th/cmp-path",
  "kristijanhusak/vim-dadbod-completion",
  "saadparwaiz1/cmp_luasnip",
  "hrsh7th/cmp-calc",
  -- LSP
  "onsails/lspkind.nvim",
  "neovim/nvim-lspconfig",
  -- Formatting
  "mhartington/formatter.nvim",
  -- Mason
  -- "williamboman/mason.nvim",
  -- "williamboman/mason-lspconfig.nvim",
  -- Icons
  "kyazdani42/nvim-web-devicons",
  -- Another
  "tpope/vim-surround",
  { "mg979/vim-visual-multi", branch = "master" },
  "djoshea/vim-autoread",
  "karb94/neoscroll.nvim",
  "nacro90/numb.nvim",
  "chentoast/marks.nvim",
  "nvim-lua/plenary.nvim",
  "tpope/vim-dotenv",
  "akinsho/bufferline.nvim",
  "lukas-reineke/indent-blankline.nvim",
  "beauwilliams/focus.nvim",
  "nvim-lualine/lualine.nvim",
  "Raimondi/delimitMate",
  "max397574/better-escape.nvim",
  "NvChad/nvim-colorizer.lua",
  "L3MON4D3/LuaSnip",
  "kazhala/close-buffers.nvim",
  "folke/lsp-trouble.nvim",
  "folke/neodev.nvim",
  "gioele/vim-autoswap",
  { "ms-jpq/coq_nvim", branch = "coq" },
  "jpalardy/vim-slime",
  "ExuCounter/diff_conflict_parts.nvim",
  "github/copilot.vim",
  {
    "mistricky/codesnap.nvim",
    build = "make",
    keys = {
      { "cc", "<cmd>CodeSnap<cr>", mode = "x", desc = "Save selected code snapshot into clipboard" },
      { "<leader>cs", "<cmd>CodeSnapSave<cr>", mode = "x", desc = "Save selected code snapshot in ~/Screenshots/" },
    },
    opts = {
      save_path = "~/Screenshots",
      watermark = "@volodymyrpotiichuk",
      code_font_family = "JetBrains Mono",
      watermark_font_family = "JetBrains Mono",
      bg_x_padding = 30,
      bg_y_padding = 82,
      has_line_number = true,
    },
    lazy = false,
  },
  -- {dir = "../custom-plugins/diff-conflict-parts/lua/init.lua"}
}

-- vim.opt.rtp:prepend "~/.config/nvim/lua/plugins/diff_conflict_parts"
