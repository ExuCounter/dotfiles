filetype plugin on
set mouse=a
set encoding=UTF-8

" UI SETTINGS
set cursorline " highlight current line
set nostartofline " don't reset cursor to start of line when moving around.
set ruler " show the cursor position
set shortmess=atI " don't show the intro message when starting Vim
set showcmd " show the (partial) command as it’s being typed
set showmatch  " highlight matching [{()}] "
set showmode " show the current mode

set hidden " allow unsaved background buffers and remember marks/undo for them
set list
set nojs " insert only one space after . ? ! with a join command
set nosol " keep the cursor in the same column when jump in file
set nu " enable line numbers
set pastetoggle=<F9>
set scrolloff=7 " minimal lines around the cursor

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

nnoremap <silent> <leader>\ :vnew<cr>
nnoremap <silent> <leader>- :new<cr

" Folds

" setlocal foldmethod=syntax
setlocal foldlevelstart=200

" set foldmethod=expr
" set foldexpr=nvim_treesitter#foldexpr()

set foldenable
set foldlevelstart=10  " default folding level when buffer is opened
set foldnestmax=10     " maximum nested fold
set foldmethod=manual

" Vim figutive

nmap <leader>go :G<CR>
nmap <leader>gr :diffget //3<CR>
nmap <leader>gl :diffget //2<CR>

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
noremap <leader>l gt
noremap <leader>h gT

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

vmap <leader>g  <Plug>(coc-format-selected)
nmap <leader>g  <Plug>(coc-format-selected)

noremap <silent> <C-S>          :update<CR>
vnoremap <silent> <C-S>         <C-C>:update<CR>
inoremap <silent> <C-S>         <C-O>:update<CR>

let g:fzf_action = {
  \ 'ctrl-w': 'tab split',
  \ 'ctrl-e': 'split',
  \ 'ctrl-r': 'vsplit' }

command! -bang -nargs=? -complete=dir Files
  \ call fzf#vim#files(<q-args>, fzf#vim#with_preview("right:50%"), <bang>0)

command! -bang -nargs=* Rg call fzf#vim#grep("rg -g '!yarn.lock' --no-heading --line-number --color=always --smart-case ".

" FZF
nnoremap <silent> <C-b> :Buffers<cr>
" nnoremap <silent> <C-p> :Rg <cr>
nnoremap <silent> <C-f> :Files <cr>
nnoremap <silent> <Leader>` :Marks<cr>
nnoremap <silent> <C-g> :GFiles?<cr>
nnoremap <silent> <C-_> :BLines<cr>
nnoremap <silent> <Leader>/ :Lines<cr>
nnoremap <silent> h: :History:<cr>
nnoremap <silent> <Leader>gb :GBranches<cr>
nnoremap <silent> <Leader>g :Git<cr>

let g:fzf_checkout_git_options = '--sort=-committerdate'

nnoremap <leader>s :w<cr>
nnoremap <Leader>fq :q!<cr>
nnoremap <Leader>q :q<cr>

nnoremap <leader>] :vsplit<cr>
nnoremap <leader>[ :split<cr>

" Clear highlighting on escape in normal mode
nnoremap <esc> :noh<return><esc>
nnoremap <esc>^[ <esc>^[

nnoremap <leader>tn :tabnew %<cr>

command! -nargs=0 Prettier :CocCommand prettier.formatFile

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

nnoremap <leader>gpu :Git push<CR>
nnoremap <leader>gpl :Git pull<CR>
nnoremap <leader>gcm :Git commit -v -q<CR>
nnoremap <leader>gam :Git commit --amend<CR>
nnoremap <leader>gcl :Gclog<CR>
nnoremap <leader>gbm :Git blame<CR>

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

" au User FugitiveIndex nmap <buffer> dt :Gtabedit <Plug><cfile><Bar>Gvdiffsplit<CR>
au User FugitiveIndex nmap <buffer> dt :Gtabedit <Plug><cfile><CR>

" Move lines by alt + arrows
nnoremap <M-Down> :m .+1<CR>==
nnoremap <M-Up> :m .-2<CR>==
inoremap <M-Down> <Esc>:m .+1<CR>==gi
inoremap <M-Up> <Esc>:m .-2<CR>==gi
vnoremap <M-Down> :m '>+1<CR>gv=gv
vnoremap <M-Up> :m '<-2<CR>gv=gv

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

" Map gwp keys to call the function
nnoremap <Leader>gbp :call PushToCurrentBranch()<CR>

xnoremap p "_dP
nnoremap <leader>d "_d
vnoremap <leader>d "_d

" let g:move_key_modifier = 'A'

set noswapfile

let g:esearch = {}
let g:esearch.adapter = 'ag'
" let g:esearch.root_markers = ['.git', 'Makefile', 'node_modules']
" let g:esearch.filetypes ='src/**/*.*'
noremap <leader>fc :call esearch#init({'paths': 'src/components/@client/'})<cr>
noremap <leader>fg :call esearch#init({'paths': 'src/graphql-tools/'})<cr>
noremap <leader>fp :call esearch#init({'paths': 'src/components/@public/'})<cr>
noremap <leader>fa :call esearch#init({'paths': 'src/components/@admin'})<cr>
noremap <leader>fa :call esearch#init({'paths': ''})

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
  }
}

EOF

let g:lognroll#enable_brackets = 0

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
" hi DiffChange guifg=NONE ctermfg=NONE guibg=#335261 ctermbg=239 gui=NONE cterm=NONE
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
let g:conflict_marker_end   = '^>>>>>>> .*$'

" Merge conflicts markers highlighting

highlight ConflictMarkerBegin guibg=#2f7366
highlight ConflictMarkerOurs guibg=#2e5049
highlight ConflictMarkerTheirs guibg=#344f69
highlight ConflictMarkerEnd guibg=#2f628e
highlight ConflictMarkerCommonAncestorsHunk guibg=#754a81

" Git rebase shortcuts

nnoremap <Leader>grc :Git rebase --continue<CR>
nnoremap <Leader>gra :Git rebase --abort
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

" Open the search window in a vertical split and reuse it for all further searches.
let g:esearch.name = '[esearch]'
let g:esearch.win_new = {esearch -> esearch#buf#goto_or_open(esearch.name, 'tabnew')}

