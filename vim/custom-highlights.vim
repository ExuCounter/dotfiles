" Coc
hi CocFloating ctermbg=Black guibg=#151515
hi CocErrorHighlight cterm=underline gui=underline
hi CocHintHighlight cterm=underline gui=underline
hi CocWarningHighlight cterm=underline gui=underline


" Matched brackets
" hi MatchParen guibg=#3e4452 ctermfg=LightGray guifg=LightGray
hi! CursorLine cterm=NONE gui=NONE term=NONE

" Blamer
hi Blamer guifg=grey guibg=#2c323c

" Merge conflicts markers highlighting
hi ConflictMarkerBegin guibg=#007566 guifg=NONE
hi ConflictMarkerOurs guibg=#1b413b 
hi ConflictMarkerTheirs guibg=#1f3a4d
hi ConflictMarkerEnd guibg=#156393 guifg=NONE 
hi ConflictMarkerSeparator guibg=#302f10 guifg=NONE 
hi ConflictMarkerCommonAncestorsHunk guibg=#2b2a0f
hi ConflictMarkerCommonAncestors guibg=#362f00

" Git diff
hi DiffAdd gui=NONE guibg=#2c406e guifg=white cterm=NONE
hi DiffDelete gui=NONE guibg=#693649 guifg=white cterm=NONE
hi DiffChange guifg=NONE ctermfg=NONE guibg=NONE ctermbg=NONE gui=NONE cterm=NONE 

hi VertSplit ctermfg=239 guifg=#303034
hi TSStrong ctermfg=249 guifg=#abb2bf
hi TSEmphasis ctermfg=249 guifg=#abb2bf
hi TSUnderline ctermfg=249 guifg=#abb2bf
hi TSText ctermfg=249 guifg=#abb2bf
hi TSTitle ctermfg=249 guifg=#abb2bf
hi CocHintSign ctermfg=11 guifg=#fab005
hi SignColumn ctermbg=NONE guibg=NONE

hi CocNONE ctermbg=NONE guibg=NONE ctermfg=NONE cterm=underline gui=underline
hi! link CocUnusedHighlight CocNONE

hi Cursor guibg=NONE ctermbg=NONE
hi Error gui=NONE

highlight IndentBlanklineChar guifg=#303034 gui=nocombine
highlight MatchParen ctermbg=238 guibg=#3e4452
highlight MatchWord ctermbg=238 guibg=#3e4452  cterm=NONE gui=NONE
hi MatchParenCur ctermbg=238 guibg=#3e4452 cterm=NONE gui=NONE
hi MatchWordCur ctermbg=238 guibg=#3e4452 cterm=NONE gui=NONE

hi cssTSError ctermfg=153 guifg=#9cdcfe

hi Folded guibg=#172630 guifg=NONE
