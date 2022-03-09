call plug#begin('~/.vim/plugged')

" UI
Plug 'christianchiarulli/nvcode-color-schemes.vim'

" Nerdtree
Plug 'preservim/nerdtree'

" Commentary
Plug 'tpope/vim-commentary'

" Git
Plug 'tpope/vim-fugitive'
Plug 'APZelos/blamer.nvim'
Plug 'brooth/far.vim'

" Coc
Plug 'neoclide/coc.nvim', {'branch': 'release'}

" DB
Plug 'tpope/vim-dadbod'
Plug 'kristijanhusak/vim-dadbod-ui'

" Fzf
Plug 'junegunn/fzf', { 'do': { -> fzf#install() }}
Plug 'junegunn/fzf.vim'

" Vim airline
Plug 'vim-airline/vim-airline'
Plug 'vim-airline/vim-airline-themes'

" Windows
Plug 'simeji/winresizer'
Plug 'matze/vim-move'

" Icons
Plug 'ryanoasis/vim-devicons'

" Syntax
Plug 'leafgarland/typescript-vim'
Plug 'nvim-treesitter/nvim-treesitter', {'do': ':TSUpdate'}
Plug 'rhysd/accelerated-jk'
Plug 'jparise/vim-graphql'
" Plug 'pangloss/vim-javascript'
Plug 'ap/vim-css-color'
Plug 'cakebaker/scss-syntax.vim', { 'for': ['sass', 'scss'] }
Plug 'hail2u/vim-css3-syntax'

" Another 
Plug 'nvim-treesitter/playground'
Plug 'airblade/vim-gitgutter'
Plug 'taku-o/vim-copypath'
Plug 'tpope/vim-surround'
Plug 'rhysd/conflict-marker.vim'
Plug 'jacquesbh/vim-showmarks'
Plug 'mg979/vim-visual-multi', {'branch': 'master'}
Plug 'easymotion/vim-easymotion' 
Plug 'Yggdroot/indentLine'
Plug 'yuttie/comfortable-motion.vim'
Plug 'christoomey/vim-tmux-navigator'
Plug 'tiagofumo/vim-nerdtree-syntax-highlight'
Plug 'djoshea/vim-autoread'
Plug 'JoosepAlviste/nvim-ts-context-commentstring'
Plug 'p00f/nvim-ts-rainbow'
Plug 'windwp/nvim-ts-autotag'
Plug 'Raimondi/delimitMate'
Plug 'jeffkreeftmeijer/vim-numbertoggle'
Plug 'karb94/neoscroll.nvim'
Plug 'nacro90/numb.nvim'
Plug 'beauwilliams/focus.nvim'

if has('nvim')
  function! UpdateRemotePlugins(...)
    " Needed to refresh runtime files
    let &rtp=&rtp
    UpdateRemotePlugins
  endfunction

  Plug 'gelguy/wilder.nvim', { 'do': function('UpdateRemotePlugins') }
else
  Plug 'gelguy/wilder.nvim'

  " To use Python remote plugin features in Vim, can be skipped
  Plug 'roxma/nvim-yarp'
  Plug 'roxma/vim-hug-neovim-rpc'
endif

call plug#end()

source ~/.vimrc

