" set foldenable          " dont fold by default
" set foldmethod=indent   " fold based on spaces
" set foldlevelstart=10   " open most folds by default
" set foldnestmax=10      " 10 nested fold max

filetype plugin indent on " required

autocmd Filetype * AnyFoldActivate               " activate for all filetypes
set foldlevel=99 " Open all folds
let g:anyfold_fold_display = 1
let g:anyfold_fold_toplevel = 1
let g:anyfold_fold_comments = 1
