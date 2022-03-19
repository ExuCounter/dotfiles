" Navigating over splits

nnoremap <C-J> <C-W><C-J>
nnoremap <C-K> <C-W><C-K>
nnoremap <C-L> <C-W><C-L>
nnoremap <C-H> <C-W><C-H>

" Fast split

nnoremap <leader>v :vnew %<cr>
nnoremap <leader>s :new %<cr>
nnoremap <leader>ev :vnew<cr>
nnoremap <leader>es :new<cr>

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
noremap <leader>l gt
map <leader>h gT

" yank/paste buffers

fu! PasteWindow(direction) "{{{
    if exists("g:yanked_buffer")
        if a:direction == 'edit'
            let temp_buffer = bufnr('%')
        endif

        exec a:direction . " +buffer" . g:yanked_buffer

        if a:direction == 'edit'
            let g:yanked_buffer = temp_buffer
        endif
    endif
endf "}}}


:nmap <silent> <leader>wy  :let g:yanked_buffer=bufnr('%')<cr>
:nmap <silent> <leader>wd  :let g:yanked_buffer=bufnr('%')<cr>:q<cr>
:nmap <silent> <leader>wp :call PasteWindow('edit')<cr>
:nmap <silent> <leader>ws :call PasteWindow('split')<cr>
:nmap <silent> <leader>wv :call PasteWindow('vsplit')<cr>
:nmap <silent> <leader>wt :call PasteWindow('tabnew')<cr>

" move to tabs

function MoveToPrevTab()
  "there is only one window
  if tabpagenr('$') == 1 && winnr('$') == 1
    return
  endif
  "preparing new window
  let l:tab_nr = tabpagenr('$')
  let l:cur_buf = bufnr('%')
  if tabpagenr() != 1
    close!
    if l:tab_nr == tabpagenr('$')
      tabprev
    endif
    sp
  else
    close!
    exe "0tabnew"
  endif
  "opening current buffer in new window
  exe "b".l:cur_buf
endfunc

function MoveToNextTab()
  "there is only one window
  if tabpagenr('$') == 1 && winnr('$') == 1
    return
  endif
  "preparing new window
  let l:tab_nr = tabpagenr('$')
  let l:cur_buf = bufnr('%')
  if tabpagenr() < tab_nr
    close!
    if l:tab_nr == tabpagenr('$')
      tabnext
    endif
    sp
  else
    close!
    tabnew
  endif
  "opening current buffer in new window
  exe "b".l:cur_buf
endfunc

" nnoremap <leader>l :call MoveToNextTab()<CR>
" nnoremap <leader>h :call MoveToPrevTab()<CR>
