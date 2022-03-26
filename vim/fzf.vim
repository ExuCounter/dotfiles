let g:fzf_action = {
  \ 'ctrl-w': 'tab split',
  \ 'ctrl-r': 'split',
  \ 'ctrl-e': 'vsplit' }

command! -bang -nargs=? -complete=dir Files
  \ call fzf#vim#files(<q-args>, fzf#vim#with_preview("right:50%"), <bang>0)

command! -bang -nargs=* Rg call fzf#vim#grep("rg -g '!yarn.lock' --no-heading --line-number --color=always --smart-case ".shellescape(<q-args>), 1, fzf#vim#with_preview({'options': '--delimiter : --nth 2..'}, 'right:50%'), <bang>0)

let g:fzf_checkout_git_options = '--sort=-committerdate'
let g:fzf_branch_actions = {
      \ 'track': {'keymap': 'ctrl-t'},
      \}
let g:fzf_layout = { 'window': { 'width': 0.9, 'height': 0.85 } }

" FZF
map <silent> <C-b> :Buffers<cr>
nmap <silent> <C-p> :Rg <cr>
nmap <silent> <C-f> :Files <cr>
" nmap <silent> <C-m> :Marks<cr>
nmap <silent> <C-g> :GFiles?<cr>
nmap <silent> <C-_> :BLines<cr>
" nmap <silent> <Leader>l :Lines<cr>
nmap <silent> <leader>h :History:<cr>

