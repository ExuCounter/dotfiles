let g:airline_section_c = '%<%F%m %#__accent_red#%{airline#util#wrap(airline#parts#readonly(),0)}%#__restore__#' 
" let g:airline#extensions#tabline#fnamemod = ':t'
let g:airline#extensions#tabline#enabled = 1
let g:airline#extensions#tabline#show_buffers = 0
" let g:airline_section_z = 0
let g:airline#extensions#coc#error_symbol = 'Errors:'
let g:airline#extensions#coc#warning_symbol = 'Warnings:'
" let g:airline#extensions#coc#open_lnum_symbol = 'Line '
let g:airline#extensions#tabline#show_splits = 0
let g:airline#extensions#tabline#show_tabs = 1
let g:airline#extensions#tabline#show_tab_nr = 0
let g:airline#extensions#tabline#show_tab_type = 0
let g:airline#extensions#tabline#close_symbol = '×'
let g:airline#extensions#tabline#show_close_button = 1
" let g:airline#extensions#tabline#formatter = 'unique_tail_improved'
let g:airline#extensions#tabline#formatter = 'short_path'

let g:airline#extensions#branch#enabled=1
let g:airline#extensions#coc#enabled = 1
let g:airline_powerline_fonts = 1

let g:airline_theme = 'solarized'

let g:airline_focuslost_inactive = 1
