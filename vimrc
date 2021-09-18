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
" set t_Co=256
set number
set termguicolors
" set background=dark
" hi Normal ctermbg=16 guibg=#0
" hi LineNr ctermbg=16 guibg=#0
" highlight NonText guibg=black
" highlight NonText guifg=black

au ColorScheme * hi Normal ctermbg=none guibg=none

" colorscheme onedark

let mapleader = " "

" hi TabLineFill ctermfg=LightGreen ctermbg=DarkGreen
" hi TabLine ctermfg=Blue ctermbg=Yellow
" hi TabLineSel ctermfg=Red ctermbg=Yellow

" Theme

" colorscheme solarized8 
"
" ONE HALF DARK

" colorscheme onehalfdark 
" let g:airline_theme='onehalfdark' 
"
" NVCODE
" let g:nvcode_termcolors=256

" colorscheme nvcode " Or whatever colorscheme you make

" " checks if your terminal has 24-bit color support
" if (has("termguicolors"))
"     set termguicolors
"     hi LineNr ctermbg=NONE guibg=NONE
" endif

" AYU

" let ayucolor="light"   " for dark version of theme
" colorscheme ayu
"

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

setlocal foldmethod=syntax
setlocal foldlevelstart=200

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
noremap <leader>h gt
noremap <leader>l gT

" Untitled txt file

noremap <leader>u :tabe untitled.txt

" set filetypes as typescriptreact
" autocmd BufNewFile,BufRead *.tsx,*.jsx set filetype=typescriptreact

" Coc settings
source ~/.vim/coc/settings.vim

" Highlight jsx/tsx
source ~/.vim/jsx-tsx-highlight/highlight.vim

" FZF
source ~/.fzf/plugin/fzf.vim

" Custom mapping

let g:coc_global_extensions = ['coc-tsserver']
command! -nargs=0 Prettier :CocCommand prettier.formatFile

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

" command! -bang -nargs=? -complete=dir Files
    " \ call fzf#vim#files(<q-args>, {'options': ['--layout=reverse', '--info=inline', '--preview', 'cat {}']}, <bang>0)

" command! -bang -nargs=* Rg call fzf#vim#grep("rg --column --line-number --no-heading --color=always --smart-case ".shellescape(<q-args>), 1, fzf#vim#with_preview("right:50%"), <bang>0) 
" command! -bang -nargs=* Rg call fzf#vim#grep("rg -g '!yarn.lock' --no-heading --line-number --color=always --smart-case ".shellescape(<q-args>), 1, fzf#vim#with_preview({'options': '--delimiter : --nth 4..'}, 'right:0%'), <bang>0) 

command! -bang -nargs=* Rg call fzf#vim#grep("rg -g '!yarn.lock' --no-heading --line-number --color=always --smart-case ".shellescape(<q-args>), 1, fzf#vim#with_preview({'options': '--delimiter : --nth 2..'}, 'right:0%'), <bang>0) 
" command! -bang -nargs=* Rg
"   \ call fzf#vim#grep(
"   \   'rg --column --line-number --no-heading --color=always --smart-case '.shellescape(<q-args>), 1,
"   \   <bang>0 ? fzf#vim#with_preview('up:60%')
"
"   \           : fzf#vim#with_preview('right:50%:hidden', '?'),
"   \   <bang>0)

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

nnoremap <leader>\ :vsplit<cr>

" Clear highlighting on escape in normal mode
nnoremap <esc> :noh<return><esc>
nnoremap <esc>^[ <esc>^[

nnoremap <leader>tn :tabnew %<cr>

command! -nargs=0 Prettier :CocCommand prettier.formatFile

inoremap <C-s> <Esc>   """ <C-s> key is <Esc> setting

let g:airline_section_c = '%F'
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


" CONF

" filenames like *.xml, *.html, *.xhtml, ...
" These are the file extensions where this plugin is enabled.
"
let g:closetag_filenames = '*.html,*.xhtml,*.phtml,*.jsx,*.tsx'

" filenames like *.xml, *.xhtml, ...
" This will make the list of non-closing tags self-closing in the specified files.
"
let g:closetag_xhtml_filenames = '*.xhtml,*.jsx,*.tsx'

" filetypes like xml, html, xhtml, ...
" These are the file types where this plugin is enabled.
"
let g:closetag_filetypes = 'html,xhtml,phtml'

" filetypes like xml, xhtml, ...
" This will make the list of non-closing tags self-closing in the specified files.
"
let g:closetag_xhtml_filetypes = 'xhtml,jsx'

" integer value [0|1]
" This will make the list of non-closing tags case-sensitive (e.g. `<Link>` will be closed while`<link>` won't.)
"
let g:closetag_emptyTags_caseSensitive = 1

" dict
" Disables auto-close if not in a "valid" region (based on filetype)
"
let g:closetag_regions = {
    \ 'typescript.tsx': 'jsxRegion,tsxRegion',
    \ 'javascript.jsx': 'jsxRegion',
    \ 'typescriptreact': 'jsxRegion,tsxRegion',
    \ 'javascriptreact': 'jsxRegion',
    \ }

" Shortcut for closing tags, default is '>'
"
let g:closetag_shortcut = '>'

" Add > at current position without closing the current tag, default is ''
"
let g:closetag_close_shortcut = '<leader>>' 

let g:airline_section_x = '%{strftime("%H:%M:%S")}'
let g:airline_theme = 'onedark'

nnoremap <leader>gpu :Git push<CR>
nnoremap <leader>gpl :Git pull<CR>
nnoremap <leader>gcm :Git commit -v -q<CR>
nnoremap <leader>gam :Git commit --amend<CR>
nnoremap <leader>gcl :Gclog<CR>

nnoremap <leader>cld :CocList diagnostics<CR>

nnoremap <leader>gco :!fbr<CR>

let g:fzf_branch_actions = {
      \ 'track': {'keymap': 'ctrl-t'},
      \}

let g:blamer_enabled = 1
let g:blamer_show_in_visual_modes = 0
let g:blamer_show_in_insert_modes = 0

" change cursor view for insert/normal mode
if !has('nvim')
  " tmux will only forward escape sequences to the terminal if surrounded by a DCS sequence
  " http://sourceforge.net/mailarchive/forum.php?thread_name=AANLkTinkbdoZ8eNR1X2UobLTeww1jFrvfJxTMfKSq-L%2B%40mail.gmail.com&forum_name=tmux-users
  if exists('$TMUX')
    let &t_SI = "\<Esc>Ptmux;\<Esc>\<Esc>]50;CursorShape=1\x7\<Esc>\\"
    let &t_SR = "\<Esc>Ptmux;\<Esc>\<Esc>]50;CursorShape=2\x7\<Esc>\\"
    let &t_EI = "\<Esc>Ptmux;\<Esc>\<Esc>]50;CursorShape=0\x7\<Esc>\\"
  else
    let &t_SI = "\<Esc>]50;CursorShape=1\x7"
    let &t_SR = "\<Esc>]50;CursorShape=2\x7"
    let &t_EI = "\<Esc>]50;CursorShape=0\x7"
  endif
endif

if !has('nvim')
  set autoread
  set backspace=indent,eol,start " enable Backspace in insert mode
  set history=10000 " remember more commands and search history
  set nocompatible
endif

let g:fzf_layout = { 'window': { 'width': 0.9, 'height': 0.7 } }

" let g:EasyGrepRoot = "repository"
" let g:EasyGrepCommand = 1
"
au User FugitiveIndex nmap <buffer> dt :Gtabedit <Plug><cfile><Bar>Gvdiffsplit<CR>

" hi DiffAdd gui=NONE guibg=#2c406e
" hi DiffDelete gui=NONE guibg=#693649

" nnoremap <M-Up> :m-2<CR>
" nnoremap <M-Down> :m+<CR>
" inoremap <M-Up> <Esc>:m-2<CR>
" inoremap <M-Down> <Esc>:m+<CR>

nnoremap <M-Down> :m .+1<CR>==
nnoremap <M-Up> :m .-2<CR>==
inoremap <M-Down> <Esc>:m .+1<CR>==gi
inoremap <M-Up> <Esc>:m .-2<CR>==gi
vnoremap <M-Down> :m '>+1<CR>gv=gv
vnoremap <M-Up> :m '<-2<CR>gv=gv

autocmd BufEnter *.{js,jsx,ts,tsx} :syntax sync fromstart
autocmd BufLeave *.{js,jsx,ts,tsx} :syntax sync clear

let g:far#window_layout = 'left'
let g:far#window_width = 80
let g:far#preview_window_height = 20
let g:far#highlight_match = 1

set lazyredraw            " improve scrolling performance when navigating through large results
set regexpengine=1        " use old regexp engine
set ignorecase smartcase  " ignore case only when the pattern contains no capital letters

" shortcut for far.vim find
" nnoremap <silent> <Leader>ff :Farf<cr>
" vnoremap <silent> <Leader>ff  :Farf<cr>

" " shortcut for far.vim replace
" nnoremap <silent> <Leader>fr :Farr<cr>
" vnoremap <silent> <Leader>fr :Farr<cr>

" let g:far#file_mask_favorites = ['/src/components/@client/**/*.*', '/src/components/@admin/**/*.*', '/src/conponents/@public/**/*.*', '/src/graphql-tools/**/*.*', '/src/graphql-tools/__generated__/schema.tsx', '/src/**/*.*']
" let g:far#default_file_mask ="" 
" let g:far#source = 'ag'
" let g:far#auto_preview=1
" let g:far#open_in_parent_window=1
" let g:far#auto_preview=1
" let g:far#auto_preview_on_start=1

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


lua <<EOF
require'nvim-treesitter.configs'.setup {
  ensure_installed = "maintained", -- one of "all", "maintained" (parsers with maintainers), or a list of languages
  highlight = {
    enable = true,              -- false will disable the whole extensio
		custom_captures={
      ["variable"] = "TSNone",
    },    -- Setting this to true will run `:h syntax` and tree-sitter at the same time.
    -- Set this to `true` if you depend on 'syntax' being enabled (like for indentation).
    -- Using this option may slow down your editor, and you may see some duplicate highlights.
    -- Instead of true it can also be a list of languages
    additional_vim_regex_highlighting = false,
  },
}
EOF

    " custom_captures={
    "  ["property"] = "TSVariable",
		 " ["variable"] = "TSType"
    " },

	  	" ["variable"] = "TSFunction",
			" ["constructor"] = "TSType",

map <Leader>f <Nop>
let g:lognroll#enable_brackets = 0
