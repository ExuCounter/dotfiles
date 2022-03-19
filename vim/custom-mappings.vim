" Return to normal mode
inoremap jj <Esc>

" EasyMotion
map S <cmd>lua require'hop'.hint_char2()<CR>
nmap s <cmd>lua require'hop'.hint_char1()<CR>
vmap s <cmd>lua require'hop'.hint_char1()<CR>
map  <silent>/ <Plug>(easymotion-sn)

" idk
vmap <C-c> <ESC>"+yi
vmap <C-x> <ESC>"+c
vmap <C-v> c<ESC>"+p
imap <C-v> <ESC>"+pa

" Copy file path
noremap <leader>cp :CopyPath<CR>

" Untitled txt file
noremap <leader>u :tabe untitled.txt

" Save on <Ctrl+s>
noremap <silent> <C-S> :update<CR>
vnoremap <silent> <C-S> <C-C>:update<CR>
inoremap <silent> <C-S> <C-O>:update<CR>

" Fast exit
nmap <Leader>q :q!<cr>

" Clear highlighting on escape in normal mode
nnoremap <esc> :noh<return><esc>
nnoremap <silent> <leader>tn :tabnew %<cr>

" idk
inoremap <C-s> <Esc>   """ <C-s> key is <Esc> setting

" Copy to buffer on delete / paste / yank
xnoremap p "_dP
nnoremap <leader>d "_d
vnoremap <leader>d "_d
noremap <leader>y "*y
noremap <leader>Y "*y$
noremap <leader>x "*x
noremap <leader>dd "*dd
noremap <leader>D "*D

" Commentary
map  gc  <Plug>Commentary
nmap gcc <Plug>CommentaryLine

command! -nargs=0 Prettier :CocCommand prettier.formatFile

" Marks
:nmap <leader>dm :delmarks A-Za-z0-9<cr>
:nmap <leader>ms :DoShowMarks!<cr>

let g:coc_default_semantic_highlight_groups = 1
