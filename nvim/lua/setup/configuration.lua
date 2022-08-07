local vimp = require("vimp")

vim.cmd(
    [[
filetype plugin on

set signcolumn=yes
set nobackup
set nowritebackup
set cmdheight=1
set updatetime=200
set shortmess+=c
set pumheight=8

set notimeout
set encoding=utf-8
set mouse=a
set cursorline " highlight current line
set nostartofline " don't reset cursor to start of line when moving around.
set ruler " show the cursor position
" set showcmd " show the (partial) command as it’s being typed

set nolist
set shortmess=atI " don't show the intro message when starting Vim
set indentexpr=
set showmatch  " highlight matching [{()}] "
set showmode " show the current mode
set hidden " allow unsaved background buffers and remember marks/undo for them
set nojs " insert only one space after . ? ! with a join command
set nosol " keep the cursor in the same column when jump in file
set scrolloff=11 " minimal lines around the cursor

set t_Co=256
set number
set noswapfile

set lazyredraw            " improve scrolling performance when navigating through large results
set regexpengine=1        " use old regexp engine
set ignorecase smartcase  " ignore case only when the pattern contains no capital letters

set timeout
set timeoutlen=500
set ttimeoutlen=100

set complete+=.,w,b,u,t,i,kspell
set completeopt=menu,menuone,noselect
set whichwrap+=<,h

syntax on
colorscheme solarized8_flat " colorscheme
set background=light
set termguicolors

set foldenable          " dont fold by default
set foldmethod=indent   " fold based on spaces
set foldlevelstart=10   " open most folds by default
set foldnestmax=10      " 10 nested fold max

set softtabstop=2
set shiftwidth=2
set tabstop=2
set expandtab
set smarttab
set autoindent
set cindent

]]
)

vim.g.mapleader = " "

vim.g.solarized_visibility = "high"
vim.g.solarized_extra_hi_groups = 1

-- vim.g.indentLine_enabled = 1
-- vim.g.indentLine_char = "│"
-- vim.g.indentLine_showFirstIndentLevel = 1

vim.g.db_ui_use_nerd_fonts = 1
vim.g.db_ui_show_database_icon = 1

vim.g.db_ui_force_echo_notifications = 1

vim.g.EasyMotion_prompt = "fast search as fuck:"
vim.g.EasyMotion_move_highlight = 0

-- vim.g.indent_blankline_show_first_indent_level = false
vim.g.matchup_matchparen_offscreen = {}

vim.g.dbs = {
    dev = {name = "prosapient_dev", url = "postgres://postgres:postgres@localhost:5432/prosapient_dev"},
    byoe = {name = "prosapient_dev_byoe", url = "postgres://postgres:postgres@localhost:5432/prosapient_dev_byoe"},
    mckinsey = {
        name = "prosapient_dev_mckinsey",
        url = "postgres://postgres:postgres@localhost:5432/prosapient_dev_mckinsey"
    },
    outreach = {
        name = "prosapient_dev_outreach",
        url = "postgres://postgres:postgres@localhost:5432/prosapient_dev_outreach"
    }
}

-- 0 = reload vimrc
vimp.nnoremap(
    "<leader>0",
    function()
        -- Remove all previously added vimpeccable maps
        vimp.unmap_all()
        -- Unload the lua namespace so that the next time require('config.X') is called
        -- it will reload the file
        require("setup/util").unload_lua_namespace("setup")
        -- Make sure all open buffers are saved
        vim.cmd("silent wa")
        -- Execute our vimrc lua file again to add back our maps
        dofile(os.getenv("HOME") .. "/nvim/lua/init.lua")

        print("Reloaded vimrc!")
    end
)
