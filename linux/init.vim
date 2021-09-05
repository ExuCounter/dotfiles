call plug#begin('~/.vim/plugged')

" UI
Plug 'ayu-theme/ayu-vim'
Plug 'challenger-deep-theme/vim', { 'as': 'challenger-deep' }
Plug 'sonph/onehalf', { 'rtp': 'vim' }

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
Plug 'stsewd/fzf-checkout.vim'

" Coc
Plug 'neoclide/coc.nvim', {'branch': 'release'}

" Syntax highlight
Plug 'leafgarland/typescript-vim'
Plug 'peitalin/vim-jsx-typescript'
Plug 'jparise/vim-graphql'

" Fzf
Plug 'junegunn/fzf', { 'dir': '~/.fzf', 'do': './install --all' }
Plug 'junegunn/fzf.vim'

call plug#end()

source ~/.vimrc
