
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



