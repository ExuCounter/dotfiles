syntax on
set t_Co=256
set number
set cursorline
set termguicolors     " enable true colors support
" let ayucolor="dark" " for mirage version of theme
" colorscheme ayu
colorscheme challenger_deep
let g:lightline = { 'colorscheme': 'challenger_deep'}

" let g:vscode_style = "dark"
" colorscheme vscode

:set listchars=eol:¬,tab:>·,trail:~,extends:>,precedes:<
:set list

let mapleader = " "

" Neomake
autocmd! BufWritePost * Neomake
" autocmd InsertLeave,TextChanged * silent! update | Neomake " fun but overhead

let g:neomake_pug_eslint_maker = {
      \ 'args': ['-f', 'compact'],
      \ 'errorformat': '%E%f: line %l\, col %c\, Error - %m,' .
      \   '%W%f: line %l\, col %c\, Warning - %m,%-G,%-G%*\d problems%#',
      \ 'cwd': '%:p:h',
      \ }

let g:neomake_elixir_enabled_makers = ['credo']
let g:neomake_javascript_enabled_makers = ['eslint']
let g:neomake_javascript_jsx_enabled_makers = ['eslint']
let g:neomake_typescript_tsx_enabled_makers = ['eslint', 'tsc']
let g:neomake_pug_enabled_makers = ['puglint', 'eslint']
let g:neomake_error_sign = {'text': 'x'}
let g:neomake_warning_sign = {'text': '!'}
let g:neomake_message_sign = {'text': '>'}
let g:neomake_info_sign = {'text': 'i'}

au BufWritePre *.tsx let b:neomake_typescript_tsx_eslint_exe = nrun#Which('eslint') |
                \ let b:neomake_typescript_tsx_tsc_exe = nrun#Which('tsc')

au BufWritePre *.js let b:neomake_javascript_eslint_exe = nrun#Which('eslint')

" if bufname('#') !~ '^fugitive:' && bufname('%') =~ '^fugitive:'
" au BufWritePre *fugitive* :!echo 1

function! s:ToggleNeomakeMarkers()
  if g:neomake_place_signs
    echo 'Disable Neomake markers'
    let g:neomake_place_signs=0
    sign unplace *
    SignifyRefresh
  else
    echo 'Enable Neomake markers'
    let g:neomake_place_signs=1
    Neomake
  endif
endfunction

nnoremap <silent> <Leader>' :call <SID>ToggleNeomakeMarkers()<CR>

let g:coc_global_extensions = ['coc-tsserver']
command! -nargs=0 Prettier :CocCommand prettier.formatFile

vmap <leader>g  <Plug>(coc-format-selected)
nmap <leader>g  <Plug>(coc-format-selected)

noremap <silent> <C-S>          :update<CR>
vnoremap <silent> <C-S>         <C-C>:update<CR>
inoremap <silent> <C-S>         <C-O>:update<CR>

" Fzf
let g:fzf_action = {
  \ 'ctrl-w': 'tab split',
  \ 'ctrl-e': 'split',
  \ 'ctrl-r': 'vsplit' }

command! -bang -nargs=? -complete=dir Files
  \ call fzf#vim#files(<q-args>, fzf#vim#with_preview(), <bang>0)

command! -bang -nargs=* Rg
  \ call fzf#vim#grep(
  \   'rg --column --line-number --no-heading --color=always --smart-case '.shellescape(<q-args>), 1,
  \   <bang>0 ? fzf#vim#with_preview('up:60%')
  \           : fzf#vim#with_preview('right:50%:hidden', '?'),
  \   <bang>0)

" Nerd Tree
nnoremap <leader>n :NERDTreeFocus<CR>
nnoremap <C-n> :NERDTree<CR>
nnoremap <C-t> :NERDTreeToggle<CR>
nnoremap <C-f> :NERDTreeFind<CR>

" FZF
nnoremap <silent> <C-b> :Buffers<cr>
nnoremap <silent> <C-f> :Rg<CR>
nnoremap <silent> <expr> <C-p> (expand('%') =~ 'NERD_tree' ? "\<c-w>\<c-w>" : '').":Files\<cr>"
nnoremap <silent> <Leader>` :Marks<cr>
nnoremap <silent> <C-g> :GFiles?<cr>
nnoremap <silent> <C-_> :BLines<cr>
nnoremap <silent> <Leader>/ :Lines<cr>
nnoremap <silent> h: :History:<cr>

" Navigating over splits
nnoremap <C-J> <C-W><C-J>
nnoremap <C-K> <C-W><C-K>
nnoremap <C-L> <C-W><C-L>
nnoremap <C-H> <C-W><C-H>

"Commentary
map  gc  <Plug>Commentary
nmap gcc <Plug>CommentaryLine

" Show hidden files
let NERDTreeShowHidden=1
let g:NERDTreeIgnore = ['^node_modules$']

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
