filetype plugin on

syntax on
set t_Co=256
set number
set termguicolors
" set background=dark
" hi Normal ctermbg=16 guibg=#0
" hi LineNr ctermbg=16 guibg=#0
" highlight NonText guibg=black
" highlight NonText guifg=black

let mapleader = " "

" hi TabLineFill ctermfg=LightGreen ctermbg=DarkGreen
" hi TabLine ctermfg=Blue ctermbg=Yellow
" hi TabLineSel ctermfg=Red ctermbg=Yellow

" Theme

colorscheme onehalfdark 

" colorscheme onehalfdark 
" let g:airline_theme='onehalfdark' 

" Commentary

map  gc  <Plug>Commentary
nmap gcc <Plug>CommentaryLine

let g:fzf_action = {
  \ 'ctrl-w': 'tab split',
  \ 'ctrl-e': 'split',
  \ 'ctrl-r': 'vsplit' }

" Nerdtree

nnoremap <leader>n :NERDTreeFocus<CR>
nnoremap <C-n> :NERDTree<CR>
nnoremap <C-t> :NERDTreeToggle<CR>
nnoremap <leader>f :NERDTreeFind<CR>

" Show hidden files in Nerd Tree

let NERDTreeShowHidden=1
let g:NERDTreeIgnore = ['^node_modules$']

" Navigating over splits

nnoremap <C-J> <C-W><C-J>
nnoremap <C-K> <C-W><C-K>
nnoremap <C-L> <C-W><C-L>
nnoremap <C-H> <C-W><C-H>

" Fast split

nnoremap <silent> <leader>\ :vnew<cr>
nnoremap <silent> <leader>- :new<cr

" Folds

setlocal foldmethod=syntax
setlocal foldlevelstart=99

" Vim figutive

nmap <leader>go :G<CR>
nmap <leader>gr :diffget //3<CR>
nmap <leader>gl :diffget //2<CR>

" Go to tab by number

noremap <leader>1 1gt
noremap <leader>2 2gt
noremap <leader>3 3gt
noremap <leader>4 4gt
noremap <leader>5 5gt
noremap <leader>6 6gt
noremap <leader>7 7gt
noremap <leader>8 8gt
noremap <leader>9 9gt
noremap <leader>h gt
noremap <leader>l gT

" Untitled txt file

noremap <leader>u :tabe untitled.txt

" set filetypes as typescriptreact
autocmd BufNewFile,BufRead *.tsx,*.jsx set filetype=typescriptreact

" Coc settings
source ~/.vim/coc/settings.vim

" Highlight jsx/tsx
source ~/.vim/jsx-tsx-highlight/highlight.vim

" Custom mapping

let g:coc_global_extensions = ['coc-tsserver']
command! -nargs=0 Prettier :CocCommand prettier.formatFile

vmap <leader>g  <Plug>(coc-format-selected)
nmap <leader>g  <Plug>(coc-format-selected)

noremap <silent> <C-S>          :update<CR>
vnoremap <silent> <C-S>         <C-C>:update<CR>
inoremap <silent> <C-S>         <C-O>:update<CR>

let g:fzf_action = {
  \ 'ctrl-w': 'tab split',
  \ 'ctrl-e': 'split',
  \ 'ctrl-r': 'vsplit' }

" FZF
nnoremap <silent> <C-b> :Buffers<cr>
nnoremap <silent> <C-f> :Files<CR>
nnoremap <silent> <expr> <C-p> (expand('%') =~ 'NERD_tree ~' ? "\<c-w>\<c-w>" : '').":Files\<cr>"
nnoremap <silent> <Leader>` :Marks<cr>
nnoremap <silent> <C-g> :GFiles?<cr>
nnoremap <silent> <C-_> :BLines<cr>
nnoremap <silent> <Leader>/ :Lines<cr>
nnoremap <silent> h: :History:<cr>
nnoremap <silent> <Leader>gb :GBranches<cr>
nnoremap <silent> <Leader>g :Git<cr>

let g:fzf_checkout_git_options = '--sort=-committerdate'

nnoremap <leader>s :w<cr>
nnoremap <Leader>fq :q!<cr>
nnoremap <Leader>q :q<cr>

command! -nargs=0 Prettier :CocCommand prettier.formatFile

