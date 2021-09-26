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

"Plug 'wesQ3/vim-windowswap'
"Plug 'wadackel/vim-dogrun'
"Plug 'vim-airline/vim-airline' | Plug 'vim-airline/vim-airline-themes'
"Plug 'Yggdroot/indentLine'

" Commentary
Plug 'tpope/vim-commentary'

" Git
Plug 'tpope/vim-fugitive' ", { 'tag': 'v3.1' }
" Plug 'stsewd/fzf-checkout.vim'
Plug 'APZelos/blamer.nvim'

" Coc
Plug 'neoclide/coc.nvim', {'branch': 'release'}

" Syntax highlight
Plug 'leafgarland/typescript-vim'
Plug 'nvim-treesitter/nvim-treesitter', {'do': ':TSUpdate'}
Plug 'nvim-treesitter/playground'
" Plug 'peitalin/vim-jsx-typescript'
Plug 'jparise/vim-graphql'
Plug 'pangloss/vim-javascript'
Plug 'ap/vim-css-color'
Plug 'cakebaker/scss-syntax.vim', { 'for': ['sass', 'scss'] }
Plug 'mattn/emmet-vim'
Plug 'eugen0329/vim-esearch'
Plug 'glippi/lognroll-vim'
Plug 'wincent/terminus'
Plug 'airblade/vim-gitgutter'
Plug 'taku-o/vim-copypath'
Plug 'styled-components/vim-styled-components', { 'branch': 'main' }
Plug 'jiangmiao/auto-pairs'
Plug 'psliwka/vim-smoothie'

" Fzf
Plug 'junegunn/fzf', { 'do': { -> fzf#install() }}
Plug 'junegunn/fzf.vim'

Plug 'vim-airline/vim-airline'
Plug 'vim-airline/vim-airline-themes'

" Plug 'dkprice/vim-easygrep'
Plug 'simeji/winresizer'

Plug 'matze/vim-move'
Plug 'brooth/far.vim'

" Icons
Plug 'ryanoasis/vim-devicons'
Plug 'tiagofumo/vim-nerdtree-syntax-highlight'

call plug#end()

source ~/.vimrc
