local Plug = vim.fn["plug#"]

vim.call("plug#begin", "~/.config/nvim/plugged")

-- UI
Plug("christianchiarulli/nvcode-color-schemes.vim")

-- Nerdtree
Plug("preservim/nerdtree")

-- Commentary
Plug("tpope/vim-commentary")

-- Git
Plug("tpope/vim-fugitive")
Plug("APZelos/blamer.nvim")
Plug("brooth/far.vim")

-- Coc
-- Plug("neoclide/coc.nvim", { branch = "release" })

-- DB
Plug("tpope/vim-dadbod")
Plug("kristijanhusak/vim-dadbod-ui")

-- Fzf
Plug("junegunn/fzf", { ["do"] = vim.fn["fzf#install"] })
Plug("junegunn/fzf.vim")

-- Vim airline
Plug("vim-airline/vim-airline")
Plug("vim-airline/vim-airline-themes")

-- Windows
Plug("simeji/winresizer")
Plug("matze/vim-move")

-- Icons
Plug("ryanoasis/vim-devicons")

-- Syntax
Plug("leafgarland/typescript-vim")
Plug("nvim-treesitter/nvim-treesitter", { ["do"] = "TSUpdate" })
Plug("rhysd/accelerated-jk")
Plug("jparise/vim-graphql")
-- Plug 'pangloss/vim-javascript'
Plug("ap/vim-css-color")
Plug("cakebaker/scss-syntax.vim", { ["for"] = { "sass", "scss" } })
Plug("hail2u/vim-css3-syntax")

-- Another
Plug("nvim-treesitter/playground")
-- Plug("airblade/vim-gitgutter")
Plug("taku-o/vim-copypath")
Plug("tpope/vim-surround")
Plug("rhysd/conflict-marker.vim")
Plug("jacquesbh/vim-showmarks")
Plug("mg979/vim-visual-multi", { branch = "master" })
Plug("phaazon/hop.nvim")
Plug("yuttie/comfortable-motion.vim")
Plug("christoomey/vim-tmux-navigator")
Plug("tiagofumo/vim-nerdtree-syntax-highlight")
Plug("djoshea/vim-autoread")
Plug("JoosepAlviste/nvim-ts-context-commentstring")
Plug("p00f/nvim-ts-rainbow")
Plug("windwp/nvim-ts-autotag")
Plug("Raimondi/delimitMate")
Plug("karb94/neoscroll.nvim")
Plug("nacro90/numb.nvim")
Plug("beauwilliams/focus.nvim")
Plug("easymotion/vim-easymotion")
Plug("andymass/vim-matchup")
Plug("yazgoo/yank-history")
Plug("chentau/marks.nvim")
Plug("nvim-lua/plenary.nvim")
Plug("tpope/vim-dotenv")
Plug("akinsho/bufferline.nvim")

Plug("gelguy/wilder.nvim")
Plug("roxma/nvim-yarp")
Plug("roxma/vim-hug-neovim-rpc")

Plug("Yggdroot/indentLine")
Plug("pseewald/vim-anyfold")
Plug("kyazdani42/nvim-web-devicons")
Plug("kyazdani42/nvim-tree.lua")
-- Plug("glepnir/dashboard-nvim")
Plug("nvim-lua/plenary.nvim")
Plug("nvim-telescope/telescope.nvim")
Plug("nvim-telescope/telescope-fzf-native.nvim", { ["do"] = vim.fn["make"] })
Plug("brooth/far.vim")
Plug("lifepillar/vim-solarized8")
Plug("nvim-telescope/telescope-media-files.nvim")
Plug("nvim-lua/popup.nvim")
Plug("wesleimp/stylua.nvim")
Plug("willelz/teastylua.nvim")
Plug("svermeulen/vimpeccable")
Plug("itchyny/vim-gitbranch")
Plug("ibhagwan/fzf-lua", { branch = "main" })
--
Plug('neovim/nvim-lspconfig')

Plug('williamboman/mason.nvim')
Plug('williamboman/mason-lspconfig.nvim')

Plug 'hrsh7th/cmp-nvim-lsp'
Plug 'hrsh7th/cmp-buffer'
Plug 'hrsh7th/cmp-path'
Plug 'hrsh7th/cmp-cmdline'
Plug 'hrsh7th/nvim-cmp'
Plug 'onsails/lspkind.nvim'

vim.call("plug#end")

