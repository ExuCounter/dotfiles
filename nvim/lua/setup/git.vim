nnoremap <leader>gcm :Git commit -v -q<CR>
nnoremap <leader>gd :Git diff 
nnoremap <leader>gcl :Gclog -50<CR>
nnoremap <leader>gl :Git log -50<CR>
nnoremap <silent> <C-g> :GFiles?<cr>
nnoremap <silent> <Leader>g :Git<cr>
nnoremap <silent> <Leader>G :Git<cr>

" Fast push/pull/fetch functions
function! PushToCurrentBranch()
  exe ":Gwrite"
  let branch = fugitive#statusline()
  let branch = substitute(branch, '\c\v\[?GIT\(([a-z0-9\-_\./:]+)\)\]?', $BRANCH.' \1', 'g')
  exe ":Git push origin" . branch
endfunction

function! PushToCurrentBranchForce()
	exe ":Gwrite"
	let branch = fugitive#statusline()
	let branch = substitute(branch, '\c\v\[?GIT\(([a-z0-9\-_\./:]+)\)\]?', $BRANCH.' \1', 'g')
	exe ":Git push origin --force" . branch
endfunction

function! PullCurrentBranch()
  exe ":Gwrite"
  let branch = fugitive#statusline()
  let branch = substitute(branch, '\c\v\[?GIT\(([a-z0-9\-_\./:]+)\)\]?', $BRANCH.' \1', 'g')
  exe ":Git pull origin" . branch
endfunction

function! FetchAllBranches()
  exe ":Gwrite"
  exe ":Git fetch --all --tags"
endfunction

" Fast push/pull/fetch git
nnoremap <Leader>gbp :call PushToCurrentBranch()<CR>
nnoremap <Leader>gbpf :call PushToCurrentBranchForce()<CR>
nnoremap <Leader>gpl :call PullCurrentBranch()<CR>
nnoremap <Leader>gfa :call FetchAllBranches()<CR>

nnoremap <leader>cld :CocList diagnostics<CR>

" Git rebase shortcuts
nnoremap <Leader>grc :Git rebase --continue<CR>
nnoremap <Leader>gra :Git rebase --abort
nnoremap <Leader>grsh :Git reset --hard
nnoremap <Leader>gri :Git rebase --interactive HEAD~
nnoremap <Leader>gcb :Git checkout -b 
nnoremap <Leader>gbl :Git blame -et<CR> 

" Git hunks
nmap <leader>ggsh <Plug>(GitGutterStageHunk)
nmap <leader>ggph <Plug>(GitGutterPreviewHunk)
nmap <leader>gguh <Plug>(GitGutterUndoHunk)

" Check git diff for file
nmap dt :tabedit %<CR>:Gdiff<CR>

au User FugitiveIndex nmap <buffer> dt :Gtabedit <Plug><cfile><Bar>Gvdiffsplit<CR>

function GStatusTabDiff()
  if has('multi_byte_encoding')
    let colon = '\%(:\|\%uff1a\)'
  else
    let colon = ':'
  endif
  let filename = matchstr(matchstr(getline(line('.')),'^#\t\zs.\{-\}\ze\%( ([^()[:digit:]]\+)\)\=$'), colon.' *\zs.*')
  tabedit %
  execute ':Gedit ' . filename
  Gvdiff
endfunction

command GStatusTabDiff call GStatusTabDiff()

autocmd FileType gitcommit noremap <buffer> dt :GStatusTabDiff<CR>

" disable the default highlight group
let g:conflict_marker_highlight_group = ''

" Include text after begin and end markers
let g:conflict_marker_begin = '^<<<<<<< .*$' 
let g:conflict_marker_common_ancestors = '^||||||| .*$'
let g:conflict_marker_separator = '^=======$'
let g:conflict_marker_end   = '^>>>>>>> .*$'

