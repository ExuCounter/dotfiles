source ~/.vim/configuration.vim
source ~/.vim/coc-settings.vim
source ~/.vim/airline.vim
source ~/.vim/folding.vim
source ~/.vim/git.vim
source ~/.vim/nerdtree.vim
source ~/.vim/treesitter.lua
source ~/.vim/windows.vim
source ~/.vim/moves.vim
source ~/.fzf/plugin/fzf.vim
source ~/.vim/fzf.vim
source ~/.vim/custom-highlights.vim
source ~/.vim/custom-mappings.vim
source ~/.vim/blamer.vim
source ~/.vim/nvim-tree.lua

nmap <C-t> :NvimTreeToggle<CR>
nnoremap <leader>r :NvimTreeRefresh<CR>
nnoremap <leader>t :NvimTreeFindFile<CR>

autocmd BufEnter * ++nested if winnr('$') == 1 && bufname() == 'NvimTree_' . tabpagenr() | quit | endif

" nnoremap <silent><leader>l :BufferLineCycleNext<CR>
" nnoremap <silent><leader>h :BufferLineCyclePrev<CR>

" nnoremap <silent><leader>1 <Cmd>BufferLineGoToBuffer 1<CR>
" nnoremap <silent><leader>2 <Cmd>BufferLineGoToBuffer 2<CR>
" nnoremap <silent><leader>3 <Cmd>BufferLineGoToBuffer 3<CR>
" nnoremap <silent><leader>4 <Cmd>BufferLineGoToBuffer 4<CR>
" nnoremap <silent><leader>5 <Cmd>BufferLineGoToBuffer 5<CR>
" nnoremap <silent><leader>6 <Cmd>BufferLineGoToBuffer 6<CR>
" nnoremap <silent><leader>7 <Cmd>BufferLineGoToBuffer 7<CR>
" nnoremap <silent><leader>8 <Cmd>BufferLineGoToBuffer 8<CR>
" nnoremap <silent><leader>9 <Cmd>BufferLineGoToBuffer 9<CR>

let s:hidden_all = 0
function! ToggleHiddenAll()
    if s:hidden_all  == 0
        let s:hidden_all = 1
        set noshowmode
        set noruler
        set laststatus=0
        set noshowcmd
    else
        let s:hidden_all = 0
        set showmode
        set ruler
        set laststatus=2
        set showcmd
    endif
endfunction

autocmd FileType dashboard set showtabline=0 | autocmd WinLeave <buffer> set showtabline=2
autocmd FileType dashboard set laststatus=0 | autocmd WinLeave <buffer> set laststatus=2
autocmd FileType dashboard set noruler | autocmd WinLeave <buffer> set ruler 
let g:indentLine_fileTypeExclude = ['dashboard']

let g:dashboard_custom_header =[
\'',
\'',
\'',
\'',
\'',
\'',
\'',
\'..... (¯`v´¯)♥',
\'.......•.¸.•´',
\'....¸.•´',
\'...(',
\'☻ /',
\'/▌♥♥',
\'/ \ ♥♥',
\]

let g:dashboard_custom_footer = [
			\"Don't worry if something doesn't work. If everything worked, you would be fired. ",
			\"- Mosher’s Law of Software Engineering"]

let g:dashboard_custom_shortcut={
\ 'last_session'       : '<leader>ls',
\ 'find_history'       : '<leader>h',
\ 'find_file'          : '<leader>f',
\ 'new_file'           : 'SPC c n',
\ 'change_colorscheme' : 'SPC t c',
\ 'find_word'          : 'SPC f a',
\ 'book_marks'         : 'SPC f b',
\ }
let g:dashboard_default_executive ='fzf'

let g:dashboard_custom_section={
  \ 'b': {
	\ 'description': ['  Find Word                 <C-p>     '],
	\ 'command': "Rg"},
  \ 'c': {
	\ 'description': ['  Exit                      leader q  '],
	\ 'command': "exit"},
  \ 'a': {
	\ 'description': ['  Find file                 <C-f>     '],
	\ 'command': "Files"}
	\ }

" nnoremap <leader>ff <cmd>Telescope find_files<cr>
" nmap <C-p> <cmd>Telescope live_grep<cr>

"     let g:fzf_colors =                                                                         
"     \ { 'fg':      ['fg', 'Normal'],                                                           
"       \ 'bg':      ['bg', 'Normal'],                                                           
"       \ 'hl':      ['fg', 'Comment'],                                                          
"       \ 'fg+':     ['fg', 'CursorLine', 'CursorColumn', 'Normal'],                             
"       \ 'bg+':     ['bg', 'CursorLine', 'CursorColumn'],                                       
"       \ 'hl+':     ['fg', 'Statement'],                                                        
"       \ 'info':    ['fg', 'PreProc'],                                                          
"       \ 'border':  ['fg', 'Ignore'],                                                           
"       \ 'prompt':  ['fg', 'Conditional'],                                                      
"       \ 'pointer': ['fg', 'Exception'],                                                        
"       \ 'marker':  ['fg', 'Keyword'],                                                          
"       \ 'spinner': ['fg', 'Label'],                                                            
"       \ 'header':  ['fg', 'Comment'] }
"       
