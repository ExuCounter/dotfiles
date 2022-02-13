filetype plugin on
set mouse=a
set encoding=UTF-8

" UI SETTINGS
set cursorline " highlight current line
set nostartofline " don't reset cursor to start of line when moving around.
set ruler " show the cursor position
set showcmd " show the (partial) command as it’s being typed
set list
set shortmess=atI " don't show the intro message when starting Vim
set showmatch  " highlight matching [{()}] "
set showmode " show the current mode

set hidden " allow unsaved background buffers and remember marks/undo for them
set nojs " insert only one space after . ? ! with a join command
set nosol " keep the cursor in the same column when jump in file
set nu " enable line numbers
set pastetoggle=<F9>
set scrolloff=10 " minimal lines around the cursor

" hi clear CursorLine
" hi CursorLine gui=underline cterm=underline

""" Customize colors
func! s:my_colors_setup() abort
	" this is an example
	hi CocFloating ctermbg=black
	" hi Pmenu guibg=transparent gui=NONE
	" hi PmenuSel guibg=white gui=NONE
	" hi PmenuSbar guibg=white
	" hi PmenuThumb guibg=white
endfunc

augroup colorscheme_coc_setup | au!
	au ColorScheme * call s:my_colors_setup()
augroup END

syntax on
" syntax enable
set t_Co=256
set number
set termguicolors

au ColorScheme * hi Normal ctermbg=none guibg=none

" colorscheme onedark

let mapleader = " "

" If you have vim >=8.0 or Neovim >= 0.1.5
if (has("termguicolors"))
set termguicolors
endif

" For Neovim 0.1.3 and 0.1.4
let $NVIM_TUI_ENABLE_TRUE_COLOR=1
let g:onedark_terminal_italics = 1
let g:onedark_termcolors = 256
let g:onedark_hide_endofbuffer = 1 

" Theme
colorscheme nvcode 
" let g:airline_theme='onedark'

" Commentary

map  gc  <Plug>Commentary
nmap gcc <Plug>CommentaryLine

" let g:fzf_action = {
"   \ 'ctrl-w': 'tab split',
"   \ 'ctrl-e': 'split',
"   \ 'ctrl-r': 'vsplit' }

" Nerdtree

nnoremap <leader>n :NERDTreeFocus<CR>
nnoremap <C-n> :NERDTree<CR>
nnoremap <C-t> :NERDTreeToggle<CR>
nmap <leader>t :NERDTreeFind<CR>

" Show hidden files in Nerd Tree

let NERDTreeShowHidden=1
let g:NERDTreeIgnore = ['^node_modules$']

" Navigating over splits

nnoremap <C-J> <C-W><C-J>
nnoremap <C-K> <C-W><C-K>
nnoremap <C-L> <C-W><C-L>
nnoremap <C-H> <C-W><C-H>

" Fast split

nnoremap <leader>v :vnew %<cr>
nnoremap <leader>s :new %<cr>

nnoremap <leader>ev :vnew<cr>
nnoremap <leader>es :new<cr>

" FOLDING
set foldenable          " dont fold by default
set foldmethod=indent   " fold based on spaces
set foldlevelstart=10   " open most folds by default
set foldnestmax=10      " 10 nested fold max

" Vim figutive

" nmap <leader>gr :diffget //3<CR>
" nmap <leader>gl :diffget //2<CR>


" Go to tab by number

noremap <leader>1 1gt
noremap <leader>2 2gt
noremap <leader>3 3gt
noremap <leader>4 4gt
noremap <leader>5 5gt
noremap <leader>6 6gt
noremap <leader>7 7gt
noremap <leader>8 8gt
noremap <leader>9 9gt
noremap <leader><Right> gt
map <leader><Left> gT

" Untitled txt file

noremap <leader>u :tabe untitled.txt

" Coc settings
source ~/.vim/coc/settings.vim

" Highlight jsx/tsx
source ~/.vim/jsx-tsx-highlight/highlight.vim

" FZF
source ~/.fzf/plugin/fzf.vim

" Custom mapping

let g:coc_global_extensions = ['coc-tsserver', 'coc-css']
command! -nargs=0 Prettier :CocCommand prettier.formatFile

autocmd FileType scss setl iskeyword+=@-@

" vmap <leader>g  <Plug>(coc-format-selected)
" nmap <leader>g  <Plug>(coc-format-selected)

noremap <silent> <C-S>          :update<CR>
vnoremap <silent> <C-S>         <C-C>:update<CR>
inoremap <silent> <C-S>         <C-O>:update<CR>

let g:fzf_action = {
  \ 'ctrl-w': 'tab split',
  \ 'ctrl-r': 'split',
  \ 'ctrl-e': 'vsplit' }

command! -bang -nargs=? -complete=dir Files
  \ call fzf#vim#files(<q-args>, fzf#vim#with_preview("right:50%"), <bang>0)

command! -bang -nargs=* Rg call fzf#vim#grep("rg -g '!yarn.lock' --no-heading --line-number --color=always --smart-case ".shellescape(<q-args>), 1, fzf#vim#with_preview({'options': '--delimiter : --nth 2..'}, 'right:50%'), <bang>0)

" FZF
nnoremap <silent> <Leader>b :Buffers<cr>
nnoremap <silent> <C-p> :Rg <cr>
nnoremap <silent> <C-f> :Files <cr>
nnoremap <silent> <Leader>' :Marks<cr>
nnoremap <silent> <C-g> :GFiles?<cr>
nnoremap <silent> <C-_> :BLines<cr>
nnoremap <silent> <Leader>/ :Lines<cr>
" nnoremap <silent> <C-h> :History:<cr>
nnoremap <silent> <Leader>gb :GBranches<cr>
nnoremap <silent> <Leader>g :Git<cr>
nnoremap <silent> <Leader>G :Git<cr>

let g:fzf_checkout_git_options = '--sort=-committerdate'

nmap <Leader>q :q!<cr>

" Clear highlighting on escape in normal mode
nnoremap <esc> :noh<return><esc>
nnoremap <esc>^[ <esc>^[

nnoremap <leader>tn :tabnew %<cr>

" command! -nargs=0 Prettier :CocCommand prettier.formatFile

inoremap <C-s> <Esc>   """ <C-s> key is <Esc> setting

let g:airline_section_c = '%<%F%m %#__accent_red#%{airline#util#wrap(airline#parts#readonly(),0)}%#__restore__#' 
let g:airline#extensions#tabline#fnamemod = ':t'
let g:airline#extensions#tabline#enabled = 1
let g:airline#extensions#tabline#show_buffers = 0
let g:airline#extensions#tabline#show_splits = 0
let g:airline#extensions#tabline#show_tabs = 1
let g:airline#extensions#tabline#show_tab_nr = 0
let g:airline#extensions#tabline#show_tab_type = 0
let g:airline#extensions#tabline#close_symbol = '×'
let g:airline#extensions#tabline#show_close_button = 0
" let g:airline#extensions#hunks#enabled=0
let g:airline#extensions#branch#enabled=1
let g:airline_powerline_fonts = 1

set shiftwidth=0
set tabstop=2

let g:airline_section_x = '%{strftime("%H:%M:%S")}'
let g:airline_theme = 'onedark'

nnoremap <leader>gcm :Git commit -v -q<CR>
nnoremap <leader>gd :Git diff 
nnoremap <leader>gcl :Gclog -50<CR>
nnoremap <leader>gl :Git log<CR>
nnoremap <leader>cld :CocList diagnostics<CR>

nnoremap <leader>gco :!fbr<CR>

let g:fzf_branch_actions = {
      \ 'track': {'keymap': 'ctrl-t'},
      \}

let g:blamer_enabled = 1
let g:blamer_show_in_visual_modes = 0
let g:blamer_show_in_insert_modes = 0

if !has('nvim')
  set autoread
  set backspace=indent,eol,start " enable Backspace in insert mode
  set history=10000 " remember more commands and search history
  set nocompatible
endif

let g:fzf_layout = { 'window': { 'width': 0.9, 'height': 0.7 } }

au User FugitiveIndex nmap <buffer> dt :Gtabedit <Plug><cfile><Bar>Gvdiffsplit<CR>
" au User FugitiveIndex nmap <buffer> dt :Gtabedit <Plug><cfile><CR>

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

" Move lines by alt + arrows
nnoremap ∆ :m .+1<CR>==
nnoremap ˚ :m .-2<CR>==
inoremap ∆ <Esc>:m .+1<CR>==gi
inoremap ˚ <Esc>:m .-2<CR>==gi
vnoremap ∆ :m '>+1<CR>gv=gv
vnoremap ˚ :m '<-2<CR>gv=gv

autocmd BufEnter *.{js,jsx,ts,tsx} :syntax sync fromstart
autocmd BufLeave *.{js,jsx,ts,tsx} :syntax sync clear

set lazyredraw            " improve scrolling performance when navigating through large results
set regexpengine=1        " use old regexp engine
set ignorecase smartcase  " ignore case only when the pattern contains no capital letters

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

" Map gwp keys to call the function
nnoremap <Leader>gbp :call PushToCurrentBranch()<CR>
nnoremap <Leader>gbpf :call PushToCurrentBranchForce()<CR>
nnoremap <Leader>gpl :call PullCurrentBranch()<CR>
nnoremap <Leader>gfa :call FetchAllBranches()<CR>

xnoremap p "_dP
nnoremap <leader>d "_d
vnoremap <leader>d "_d

" let g:move_key_modifier = 'A'

set noswapfile

" Tree sitter ( Syntax highlight )

lua <<EOF
require'nvim-treesitter.configs'.setup {
  ensure_installed = "maintained", -- one of "all", "maintained" (parsers with maintainers), or a list of languages
  highlight = {
    enable = true,              -- false will disable the whole extensio
    additional_vim_regex_highlighting = false,
  },
  indent = {
    enable = true
  },
  autotag = {
    enable = true,
  },
  context_commentstring = {
    enable = true,
    enable_autocmd = false
  }
}

EOF

let g:lognroll#enable_brackets = 0
let g:lognroll#enable_insert_mode = 0

vmap <C-c> <ESC>"+yi
vmap <C-x> <ESC>"+c
vmap <C-v> c<ESC>"+p
imap <C-v> <ESC>"+pa

" Copy file path
noremap <leader>cp :CopyPath<CR>

" Styled components clear buffers to prevent vim lagging

autocmd BufEnter *.{js,jsx,ts,tsx} :syntax sync fromstart
autocmd BufLeave *.{js,jsx,ts,tsx} :syntax sync clear

" Search in file by selecting
vnoremap // y/\V<C-R>=escape(@",'/\')<CR><CR>

hi DiffAdd gui=NONE guibg=#2c406e guifg=white
hi DiffDelete gui=NONE guibg=#693649 guifg=white

" hi DiffAdd guifg=NONE ctermfg=NONE guibg=#464632 ctermbg=238 gui=NONE cterm=NONE
hi DiffChange guifg=NONE ctermfg=NONE guibg=#335261 ctermbg=239 gui=NONE cterm=NONE
" hi DiffDelete guifg=#f43753 ctermfg=203 guibg=#79313c ctermbg=237 gui=NONE cterm=NONE
" hi DiffText guifg=NONE ctermfg=NONE guibg=NONE ctermbg=NONE gui=reverse cterm=reverse

" Disable default vim figutive colors

" hi DiffAdd guifg=NONE ctermfg=NONE guibg=NONE ctermbg=NONE gui=NONE cterm=NONE
" hi DiffChange guifg=NONE ctermfg=NONE guibg=NONE ctermbg=NONE gui=NONE cterm=NONE
" hi DiffDelete guifg=NONE ctermfg=NONE guibg=NONE ctermbg=NONE gui=NONE cterm=NONE
" hi DiffText guifg=NONE ctermfg=NONE guibg=NONE ctermbg=NONE gui=reverse cterm=reverse


" disable the default highlight group
let g:conflict_marker_highlight_group = ''

" Include text after begin and end markers
let g:conflict_marker_begin = '^<<<<<<< .*$' 
let g:conflict_marker_common_ancestors = '^||||||| .*$'
let g:conflict_marker_separator = '^=======$'
let g:conflict_marker_end   = '^>>>>>>> .*$'

" Merge conflicts markers highlighting

highlight ConflictMarkerBegin guibg=#007566 guifg=NONE
highlight ConflictMarkerOurs guibg=#1b413b 
highlight ConflictMarkerTheirs guibg=#1f3a4d
highlight ConflictMarkerEnd guibg=#156393 guifg=NONE 
highlight ConflictMarkerSeparator guibg=#302f10 guifg=NONE 
highlight ConflictMarkerCommonAncestorsHunk guibg=#2b2a0f
highlight ConflictMarkerCommonAncestors guibg=#362f00
" Git rebase shortcuts

nnoremap <Leader>grc :Git rebase --continue<CR>
nnoremap <Leader>gra :Git rebase --abort
nnoremap <Leader>grsh :Git reset --hard
nnoremap <Leader>gri :Git rebase --interactive HEAD~

" Git Blamer vim

highlight Blamer guifg=grey
let g:blamer_relative_time = 1
let g:blamer_date_format = '%d/%m/%y'
let g:blamer_delay = 0

augroup VimCSS3Syntax
  autocmd!

  autocmd FileType css setlocal iskeyword+=-
augroup END

function MoveToPrevTab()
  "there is only one window
  if tabpagenr('$') == 1 && winnr('$') == 1
    return
  endif
  "preparing new window
  let l:tab_nr = tabpagenr('$')
  let l:cur_buf = bufnr('%')
  if tabpagenr() != 1
    close!
    if l:tab_nr == tabpagenr('$')
      tabprev
    endif
    sp
  else
    close!
    exe "0tabnew"
  endif
  "opening current buffer in new window
  exe "b".l:cur_buf
endfunc

function MoveToNextTab()
  "there is only one window
  if tabpagenr('$') == 1 && winnr('$') == 1
    return
  endif
  "preparing new window
  let l:tab_nr = tabpagenr('$')
  let l:cur_buf = bufnr('%')
  if tabpagenr() < tab_nr
    close!
    if l:tab_nr == tabpagenr('$')
      tabnext
    endif
    sp
  else
    close!
    tabnew
  endif
  "opening current buffer in new window
  exe "b".l:cur_buf
endfunc

nmap dt :tabedit %<CR>:Gdiff<CR>

nnoremap <leader>l :call MoveToNextTab()<CR>
nnoremap <leader>h :call MoveToPrevTab()<CR>

fu! PasteWindow(direction) "{{{
    if exists("g:yanked_buffer")
        if a:direction == 'edit'
            let temp_buffer = bufnr('%')
        endif

        exec a:direction . " +buffer" . g:yanked_buffer

        if a:direction == 'edit'
            let g:yanked_buffer = temp_buffer
        endif
    endif
endf "}}}

"yank/paste buffers
:nmap <silent> <leader>wy  :let g:yanked_buffer=bufnr('%')<cr>
:nmap <silent> <leader>wd  :let g:yanked_buffer=bufnr('%')<cr>:q<cr>
:nmap <silent> <leader>wp :call PasteWindow('edit')<cr>
:nmap <silent> <leader>ws :call PasteWindow('split')<cr>
:nmap <silent> <leader>wv :call PasteWindow('vsplit')<cr>
:nmap <silent> <leader>wt :call PasteWindow('tabnew')<cr>

:nmap <leader>dm :delmarks A-Za-z0-9<cr>
:nmap <leader>ms :DoShowMarks!<cr>

nmap <leader>ggph <Plug>(GitGutterPreviewHunk)
nmap <leader>ggsh <Plug>(GitGutterStageHunk)
nmap <leader>gguh <Plug>(GitGutterUndoHunk)

noremap <leader>y "*y
" noremap <leader>yy "*yy
noremap <leader>Y "*y$
noremap <leader>x "*x
noremap <leader>dd "*dd
noremap <leader>D "*D

" EasyMotion
map  / <Plug>(easymotion-sn)
omap / <Plug>(easymotion-tn)

let g:accelerated_jk_acceleration_limit = 500 

nmap j <Plug>(accelerated_jk_gj)
nmap k <Plug>(accelerated_jk_gk)

let g:accelerated_jk_acceleration_table = [30,60]

" Disable Arrow keys in Normal mode
map <up> <nop>
map <down> <nop>
map <left> <nop>
map <right> <nop>

" Disable Arrow keys in Insert mode
imap <up> <nop>
imap <down> <nop>
imap <left> <nop>
imap <right> <nop>

inoremap jk <Esc>

let g:comfortable_motion_no_default_key_mappings = 1

nnoremap <silent> <C-d> :call comfortable_motion#flick(100)<CR>
nnoremap <silent> <C-u> :call comfortable_motion#flick(-100)<CR>

let g:comfortable_motion_impulse_multiplier = 1  " Feel free to increase/decrease this value.
nnoremap <silent> <C-d> :call comfortable_motion#flick(g:comfortable_motion_impulse_multiplier * winheight(0) * 2)<CR>
nnoremap <silent> <C-u> :call comfortable_motion#flick(g:comfortable_motion_impulse_multiplier * winheight(0) * -2)<CR>

let g:comfortable_motion_friction = 80.0
let g:comfortable_motion_air_drag = 10.0

autocmd FileType fugitiveblame nmap <buffer> q gq

" Ultisnips

" Use <C-j> for jump to next placeholder, it's default of coc.nvim
let g:coc_snippet_next = '<c-l>'

" Use <C-k> for jump to previous placeholder, it's default of coc.nvim
let g:coc_snippet_prev = '<c-h>'

autocmd User EasyMotionPromptBegin silent! CocDisable
autocmd User EasyMotionPromptEnd silent! CocEnable


" Close tag

let g:closetag_filenames = '*.html,*.tsx,*.jsx'
let g:closetag_xhtml_filenames = '*.xhtml'
let g:closetag_filetypes = 'html,xhtml,phtml,jsx,tsx'
let g:closetag_xhtml_filetypes = 'xhtml,jsx,tsx'
let g:closetag_emptyTags_caseSensitive = 1
let g:closetag_shortcut = '>'
let g:closetag_regions =  {
\ 'typescript.tsx': 'jsxRegion,tsxRegion',
\ 'javascript.jsx': 'jsxRegion',
\ }


