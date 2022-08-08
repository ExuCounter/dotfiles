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

-- DB
Plug("tpope/vim-dadbod")
Plug("kristijanhusak/vim-dadbod-ui")

-- Fzf
Plug("ibhagwan/fzf-lua", {branch = "main"})

-- Windows
Plug("simeji/winresizer")
Plug("matze/vim-move")

-- Icons
Plug("ryanoasis/vim-devicons")

-- Syntax
Plug("leafgarland/typescript-vim")
Plug("nvim-treesitter/nvim-treesitter", {["do"] = "TSUpdate"})
Plug("rhysd/accelerated-jk")
Plug("jparise/vim-graphql")

-- Another
Plug("nvim-treesitter/playground")
Plug("taku-o/vim-copypath")
Plug("tpope/vim-surround")
Plug("rhysd/conflict-marker.vim")
Plug("jacquesbh/vim-showmarks")
Plug("mg979/vim-visual-multi", {branch = "master"})
Plug("phaazon/hop.nvim")
Plug("yuttie/comfortable-motion.vim")
Plug("christoomey/vim-tmux-navigator")
Plug("djoshea/vim-autoread")
Plug("JoosepAlviste/nvim-ts-context-commentstring")
Plug("p00f/nvim-ts-rainbow")
Plug("windwp/nvim-ts-autotag")
Plug("karb94/neoscroll.nvim")
Plug("nacro90/numb.nvim")
Plug("beauwilliams/focus.nvim")
Plug("easymotion/vim-easymotion")
Plug("andymass/vim-matchup")
Plug("yazgoo/yank-history")
Plug "chentoast/marks.nvim"
Plug("nvim-lua/plenary.nvim")
Plug("tpope/vim-dotenv")
Plug("akinsho/bufferline.nvim")
Plug("cohama/lexima.vim")

Plug("gelguy/wilder.nvim")
Plug("roxma/nvim-yarp")
Plug("roxma/vim-hug-neovim-rpc")

Plug("lukas-reineke/indent-blankline.nvim")
Plug("pseewald/vim-anyfold")
Plug("kyazdani42/nvim-web-devicons")
Plug("kyazdani42/nvim-tree.lua")
-- Plug("glepnir/dashboard-nvim")
--
Plug("brooth/far.vim")
Plug("svermeulen/vimpeccable")
Plug("itchyny/vim-gitbranch")
--
Plug("neovim/nvim-lspconfig")

Plug("williamboman/mason.nvim")
Plug("williamboman/mason-lspconfig.nvim")

Plug("hrsh7th/cmp-nvim-lsp")
Plug("hrsh7th/cmp-buffer")
Plug("hrsh7th/cmp-path")
Plug("hrsh7th/cmp-cmdline")
Plug("hrsh7th/nvim-cmp")
Plug("onsails/lspkind.nvim")
Plug("lukas-reineke/lsp-format.nvim")
Plug("sbdchd/neoformat")
Plug("mhartington/formatter.nvim")
Plug "SirVer/ultisnips"
Plug "ray-x/lsp_signature.nvim"
Plug "lewis6991/gitsigns.nvim"
Plug "nvim-lualine/lualine.nvim"

vim.call("plug#end")
