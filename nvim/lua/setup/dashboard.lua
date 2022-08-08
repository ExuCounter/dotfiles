vim.cmd(
    [[
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

  ]]
)
