local Plug = vim.fn["plug#"]

vim.call("plug#begin", "~/.config/nvim/plugged")

-- UI
Plug("lifepillar/vim-solarized8")

-- FileTree
Plug("kyazdani42/nvim-tree.lua")

-- Commentary
Plug("tpope/vim-commentary")

-- Git
Plug("tpope/vim-fugitive")
Plug("APZelos/blamer.nvim")
Plug("brooth/far.vim")
Plug("itchyny/vim-gitbranch")
Plug("lewis6991/gitsigns.nvim")
Plug("rhysd/conflict-marker.vim")

-- DB
Plug("tpope/vim-dadbod")
Plug("kristijanhusak/vim-dadbod-ui")

-- Fzf
Plug("ibhagwan/fzf-lua", {branch = "main"})

-- Windows
Plug("christoomey/vim-tmux-navigator")
Plug("simeji/winresizer")
Plug("matze/vim-move")

-- Moves
Plug("rhysd/accelerated-jk")
Plug("phaazon/hop.nvim")

-- Syntax
Plug("nvim-treesitter/nvim-treesitter", {["do"] = "TSUpdate"})
Plug("JoosepAlviste/nvim-ts-context-commentstring")
Plug("windwp/nvim-ts-autotag")

-- CMP
Plug("hrsh7th/cmp-nvim-lsp")
Plug("hrsh7th/cmp-buffer")
Plug("hrsh7th/cmp-cmdline")
Plug("hrsh7th/nvim-cmp")
Plug("tzachar/cmp-tabnine", {["do"] = "./install.sh"})

-- LSP
Plug("onsails/lspkind.nvim")
Plug("neovim/nvim-lspconfig")

-- Formatting
Plug("mhartington/formatter.nvim")

-- Mason
Plug("williamboman/mason.nvim")
Plug("williamboman/mason-lspconfig.nvim")

-- Icons
Plug("kyazdani42/nvim-web-devicons")

-- Another
Plug("taku-o/vim-copypath")
Plug("tpope/vim-surround")
Plug("mg979/vim-visual-multi", {branch = "master"})
Plug("djoshea/vim-autoread")
Plug("karb94/neoscroll.nvim")
Plug("nacro90/numb.nvim")
Plug("chentoast/marks.nvim")
Plug("nvim-lua/plenary.nvim")
Plug("tpope/vim-dotenv")
Plug("akinsho/bufferline.nvim")
Plug("lukas-reineke/indent-blankline.nvim")
Plug("beauwilliams/focus.nvim")
Plug("svermeulen/vimpeccable")
Plug "SirVer/ultisnips"
Plug "nvim-lualine/lualine.nvim"
-- Plug "cohama/lexima.vim"
Plug "Raimondi/delimitMate"
Plug "max397574/better-escape.nvim"
-- Plug("glepnir/dashboard-nvim")
--

vim.call("plug#end")
