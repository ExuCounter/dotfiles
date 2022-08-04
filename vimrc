" source ~/.vim/configuration.vim
" source ~/.vim/configuration.lua
" source ~/.vim/coc-settings.vim
" source ~/.vim/airline.vim
" source ~/.vim/folding.vim
" source ~/.vim/git.vim
" source ~/.vim/nerdtree.vim
" source ~/.vim/treesitter.lua
" source ~/.vim/windows.vim
" source ~/.vim/moves.vim
" source ~/.fzf/plugin/fzf.vim
" source ~/.vim/fzf.vim
" source ~/.vim/custom-highlights.vim
" source ~/.vim/custom-mappings.vim
" source ~/.vim/blamer.vim
" source ~/.vim/nvim-tree.lua
" source ~/.vim/bufferline.lua

nmap <C-t> :NvimTreeToggle<CR>
nnoremap <leader>r :NvimTreeRefresh<CR>
nnoremap <leader>t :NvimTreeFindFile<CR>

"autocmd BufEnter * ++nested if winnr('$') == 1 && bufname() == 'NvimTree_' . tabpagenr() | quit | endif

""let s:hidden_all = 0
"function! ToggleHiddenAll()
"    if s:hidden_all  == 0
"        let s:hidden_all = 1
"        set noshowmode
"        set noruler
"        set laststatus=0
"        set noshowcmd
"    else
"        let s:hidden_all = 0
"        set showmode
"        set ruler
"        set laststatus=2
"        set showcmd
"    endif
"endfunction

"autocmd FileType dashboard set showtabline=0 | autocmd WinLeave <buffer> set showtabline=2
"autocmd FileType dashboard set laststatus=0 | autocmd WinLeave <buffer> set laststatus=2
"autocmd FileType dashboard set noruler | autocmd WinLeave <buffer> set ruler 
"let g:indentLine_fileTypeExclude = ['dashboard']

"let g:dashboard_custom_header =[
"\'',
"\'',
"\'',
"\'',
"\'',
"\'',
"\'',
"\'..... (¯`v´¯)♥',
"\'.......•.¸.•´',
"\'....¸.•´',
"\'...(',
"\'☻ /',
"\'/▌♥♥',
"\'/ \ ♥♥',
"\]

"let g:dashboard_custom_footer = [
"			\"Don't worry if something doesn't work. If everything worked, you would be fired. ",
"			\"- Mosher’s Law of Software Engineering"]

"let g:dashboard_custom_shortcut={
"\ 'last_session'       : '<leader>ls',
"\ 'find_history'       : '<leader>h',
"\ 'find_file'          : '<leader>f',
"\ 'new_file'           : 'SPC c n',
"\ 'change_colorscheme' : 'SPC t c',
"\ 'find_word'          : 'SPC f a',
"\ 'book_marks'         : 'SPC f b',
"\ }
"let g:dashboard_default_executive ='fzf'

"let g:dashboard_custom_section={
"  \ 'b': {
"	\ 'description': ['  Find Word                 <C-p>     '],
"	\ 'command': "Rg"},
"  \ 'c': {
"	\ 'description': ['  Exit                      leader q  '],
"	\ 'command': "exit"},
"  \ 'a': {
"	\ 'description': ['  Find file                 <C-f>     '],
"	\ 'command': "Files"}
"	\ }


"nnoremap <silent><leader>1 <cmd>lua require("bufferline").go_to_buffer(1, true)<cr>
"nnoremap <silent><leader>2 <cmd>lua require("bufferline").go_to_buffer(2, true)<cr>
"nnoremap <silent><leader>3 <cmd>lua require("bufferline").go_to_buffer(3, true)<cr>
"nnoremap <silent><leader>4 <cmd>lua require("bufferline").go_to_buffer(4, true)<cr>
"nnoremap <silent><leader>5 <cmd>lua require("bufferline").go_to_buffer(5, true)<cr>
"nnoremap <silent><leader>6 <cmd>lua require("bufferline").go_to_buffer(6, true)<cr>
"nnoremap <silent><leader>7 <cmd>lua require("bufferline").go_to_buffer(7, true)<cr>
"nnoremap <silent><leader>8 <cmd>lua require("bufferline").go_to_buffer(8, true)<cr>
"nnoremap <silent><leader>9 <cmd>lua require("bufferline").go_to_buffer(9, true)<cr>
"nnoremap <silent><leader>$ <cmd>lua require("bufferline").go_to_buffer(-1, true)<cr>
