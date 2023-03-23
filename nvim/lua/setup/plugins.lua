local ensure_packer = function()
    local fn = vim.fn
    local install_path = fn.stdpath("data") .. "/site/pack/packer/start/packer.nvim"
    if fn.empty(fn.glob(install_path)) > 0 then
        fn.system({"git", "clone", "--depth", "1", "https://github.com/wbthomason/packer.nvim", install_path})
        vim.cmd [[packadd packer.nvim]]
        return true
    end
    return false
end

local packer_bootstrap = ensure_packer()

return require("packer").startup(
    function(use)
        use "wbthomason/packer.nvim"
        -- UI
        use "lifepillar/vim-solarized8"
        use {"catppuccin/nvim", as = "catppuccin"}
        -- FileTree
        use "kyazdani42/nvim-tree.lua"
        -- Commentary
        use "tpope/vim-commentary"

        -- Git
        use "tpope/vim-fugitive"
        use "brooth/far.vim"
        use "itchyny/vim-gitbranch"
        use "lewis6991/gitsigns.nvim"
        use "rhysd/conflict-marker.vim"

        -- DB
        use "tpope/vim-dadbod"
        use "kristijanhusak/vim-dadbod-ui"

        -- Fzf
        use {"ibhagwan/fzf-lua", branch = "main"}

        -- Windows
        use "christoomey/vim-tmux-navigator"
        use "simeji/winresizer"

        -- Moves
        use "rhysd/accelerated-jk"
        use "phaazon/hop.nvim"

        -- Syntax
        use {"nvim-treesitter/nvim-treesitter", run = ":TSUpdate"}
        use {"JoosepAlviste/nvim-ts-context-commentstring", requires = {"nvim-treesitter/nvim-treesitter"}}
        use {"windwp/nvim-ts-autotag", requires = {"nvim-treesitter/nvim-treesitter"}}

        -- CMP
        use "hrsh7th/cmp-nvim-lsp"
        use "hrsh7th/cmp-buffer"
        use {"hrsh7th/cmp-cmdline", commit = "d2dfa338520c99c1f2dc6af9388de081a6e63296"}
        use "hrsh7th/nvim-cmp"
        use "hrsh7th/cmp-nvim-lsp-signature-help"
        use "hrsh7th/cmp-path"
        use "kristijanhusak/vim-dadbod-completion"
        use "hrsh7th/cmp-calc"

        -- LSP
        use "onsails/lspkind.nvim"
        use "neovim/nvim-lspconfig"

        -- Formatting
        use "mhartington/formatter.nvim"

        -- Mason
        use "williamboman/mason.nvim"
        use "williamboman/mason-lspconfig.nvim"

        -- Icons
        use "kyazdani42/nvim-web-devicons"

        -- Another
        use "tpope/vim-surround"
        use {"mg979/vim-visual-multi", branch = "master"}
        use "djoshea/vim-autoread"
        use "karb94/neoscroll.nvim"
        use "nacro90/numb.nvim"
        use "chentoast/marks.nvim"
        use "nvim-lua/plenary.nvim"
        use "tpope/vim-dotenv"
        use "akinsho/bufferline.nvim"
        use "lukas-reineke/indent-blankline.nvim"
        use "beauwilliams/focus.nvim"
        use "nvim-lualine/lualine.nvim"
        use "Raimondi/delimitMate"
        use "max397574/better-escape.nvim"
        use "NvChad/nvim-colorizer.lua"
        use "L3MON4D3/LuaSnip"
        use "saadparwaiz1/cmp_luasnip"
        use "kazhala/close-buffers.nvim"
        use "folke/lsp-trouble.nvim"
        use "folke/neodev.nvim"

        if packer_bootstrap then
            require("packer").sync()
        end
    end
)
