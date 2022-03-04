call plug#begin('~/.vim/plugged')

" UI
Plug 'ayu-theme/ayu-vim'
Plug 'challenger-deep-theme/vim', { 'as': 'challenger-deep' }
Plug 'sonph/onehalf', { 'rtp': 'vim' }
Plug 'lifepillar/vim-solarized8'
Plug 'arcticicestudio/nord-vim'
Plug 'christianchiarulli/nvcode-color-schemes.vim'
Plug 'jacoborus/tender.vim'
Plug 'joshdick/onedark.vim'

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
Plug 'jparise/vim-graphql'
Plug 'pangloss/vim-javascript'
Plug 'ap/vim-css-color'
Plug 'cakebaker/scss-syntax.vim', { 'for': ['sass', 'scss'] }
Plug 'hail2u/vim-css3-syntax'
Plug 'cakebaker/scss-syntax.vim'

" Another 
Plug 'nvim-treesitter/playground'
Plug 'mattn/emmet-vim'
Plug 'eugen0329/vim-esearch'
Plug 'glippi/lognroll-vim'
Plug 'wincent/terminus'
Plug 'airblade/vim-gitgutter'
Plug 'taku-o/vim-copypath'
Plug 'psliwka/vim-smoothie'
Plug 'tpope/vim-surround'
Plug 'rhysd/conflict-marker.vim'
Plug 'jacquesbh/vim-showmarks'
Plug 'mg979/vim-visual-multi', {'branch': 'master'}
Plug 'easymotion/vim-easymotion' 
Plug 'Yggdroot/indentLine'
Plug 'rhysd/accelerated-jk'
Plug 'yuttie/comfortable-motion.vim'
Plug 'christoomey/vim-tmux-navigator'
Plug 'tiagofumo/vim-nerdtree-syntax-highlight'
Plug 'djoshea/vim-autoread'
Plug 'JoosepAlviste/nvim-ts-context-commentstring'
Plug 'p00f/nvim-ts-rainbow'
Plug 'windwp/nvim-ts-autotag'
Plug 'Raimondi/delimitMate'

Plug 'nacro90/numb.nvim'
Plug 'karb94/neoscroll.nvim'
Plug 'brooth/far.vim'
Plug 'jeffkreeftmeijer/vim-numbertoggle'
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

