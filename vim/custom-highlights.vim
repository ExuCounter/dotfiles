" " Coc
" hi CocFloating ctermbg=Black guibg=#151515
hi CocErrorHighlight cterm=underline gui=underline
hi CocHintHighlight cterm=underline gui=underline
hi CocWarningHighlight cterm=underline gui=underline

" disable the default highlight group
let g:conflict_marker_highlight_group = ''

" Include text after begin and end markers
let g:conflict_marker_begin = '^<<<<<<< .*$'
let g:conflict_marker_end   = '^>>>>>>> .*$'

" " Matched brackets
" " hi MatchParen guibg=#3e4452 ctermfg=LightGray guifg=LightGray
hi! CursorLine cterm=NONE gui=NONE term=NONE

" " Blamer
" hi Blamer guifg=grey guibg=#2c323c

" " Merge conflicts markers highlighting
function! HighlightConflictMarker() abort
   hi ConflictMarkerBegin guibg=#e6cd85 guifg=#FFFFFF
   hi ConflictMarkerOurs guibg=#FAEFD1
   hi ConflictMarkerTheirs guibg=#DDEFFA
   hi ConflictMarkerEnd guibg=#F5DDDC guifg=NONE 
   hi ConflictMarkerSeparator guibg=NONE guifg=NONE 
   hi ConflictMarkerCommonAncestorsHunk guibg=NONE
   hi ConflictMarkerCommonAncestors guibg=NONE
endfunction

call timer_start(200, { tid -> execute('call HighlightConflictMarker()') })

" " Git diff
" hi DiffAdd gui=NONE guibg=#2c406e guifg=white cterm=NONE
" hi DiffDelete gui=NONE guibg=#693649 guifg=white cterm=NONE
" hi DiffChange guifg=NONE ctermfg=NONE guibg=NONE ctermbg=NONE gui=NONE cterm=NONE 

hi VertSplit ctermbg=NONE guibg=NONE
hi BufferLineFill ctermbg=254 guibg=#eee8d5
hi BufferLineErrorDiagnostic guifg=red guibg=#ded8c7
hi BufferLineError guifg=red guibg=#ded8c7
hi BufferLineWarningDiagnostic guifg=yellow guibg=#ded8c7
hi BufferLineWarning guifg=yellow guibg=#ded8c7
" hi TSStrong ctermfg=249 guifg=#abb2bf
" hi TSEmphasis ctermfg=249 guifg=#abb2bf
" hi TSUnderline ctermfg=249 guifg=#abb2bf
" hi TSText ctermfg=249 guifg=#abb2bf
" hi TSTitle ctermfg=249 guifg=#abb2bf
" hi CocHintSign ctermfg=11 guifg=#fab005
" hi SignColumn ctermbg=NONE guibg=NONE

hi CocNONE ctermbg=NONE guibg=NONE ctermfg=NONE cterm=underline gui=underline
hi! link CocUnusedHighlight CocNONE

hi Cursor guibg=#657b83 ctermbg=NONE guifg=#FFFFFF
hi Error gui=NONE

" highlight IndentBlanklineChar guifg=#303034 gui=nocombine
" highlight MatchParen ctermbg=238 guibg=#3e4452
" highlight MatchWord ctermbg=238 guibg=#3e4452  cterm=NONE gui=NONE
" hi MatchParenCur ctermbg=238 guibg=#3e4452 cterm=NONE gui=NONE
" hi MatchWordCur ctermbg=238 guibg=#3e4452 cterm=NONE gui=NONE

" hi cssTSError ctermfg=153 guifg=#9cdcfe

" hi Folded guibg=#172630 guifg=NONE
"
" hi HopNextKey1 guifg=#6c71c4 cterm=bold gui=bold
" hi HopNextKey2 guifg=#cb4b16 cterm=bold gui=bold
" hi HopUnmatched ctermfg=NONE guifg=#888888
