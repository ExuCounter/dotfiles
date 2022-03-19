filetype plugin on

set mouse=a
set encoding=UTF-8

syntax on

au ColorScheme * hi Normal ctermbg=none guibg=none

colorscheme nvcode " colorscheme

augroup colorscheme_coc_setup | au!
 au ColorScheme * call s:my_colors_setup()
augroup END

set timeout timeoutlen=500 ttimeoutlen=100 " fix slow O inserts
set ve=block " allow put the cursor anyway in visual block mode
set complete=.,w,b,u,t,i,kspell

" If you have vim >=8.0 or Neovim >= 0.1.5
if (has("termguicolors"))
set termguicolors
endif

" For Neovim 0.1.3 and 0.1.4
let $NVIM_TUI_ENABLE_TRUE_COLOR=1
let g:onedark_terminal_italics = 1
let g:onedark_termcolors = 256
let g:onedark_hide_endofbuffer = 1 

" autocmd FileType scss setl iskeyword+=@-@

" Styled components clear buffers to prevent vim lagging
autocmd BufEnter *.{js,jsx,ts,tsx} :syntax sync fromstart
autocmd BufLeave *.{js,jsx,ts,tsx} :syntax sync clear

augroup VimCSS3Syntax
  autocmd!

  autocmd FileType css setlocal iskeyword+=-
augroup END

autocmd FileType scss setl iskeyword+=@-@

if !has('nvim')
  set autoread
  set backspace=indent,eol,start " enable Backspace in insert mode
  set history=10000 " remember more commands and search history
  set nocompatible
endif

set t_Co=256
set number
set noswapfile

set lazyredraw            " improve scrolling performance when navigating through large results
set regexpengine=1        " use old regexp engine
set ignorecase smartcase  " ignore case only when the pattern contains no capital letters

let mapleader = "\<Space>" " leader key

set cursorline " highlight current line
set nostartofline " don't reset cursor to start of line when moving around.
set ruler " show the cursor position
" set showcmd " show the (partial) command as it’s being typed
set list
set shortmess=atI " don't show the intro message when starting Vim
set showmatch  " highlight matching [{()}] "
set showmode " show the current mode

set hidden " allow unsaved background buffers and remember marks/undo for them
set nojs " insert only one space after . ? ! with a join command
set nosol " keep the cursor in the same column when jump in file
set scrolloff=11 " minimal lines around the cursor
set shiftwidth=0
set tabstop=2
set numberwidth=5

" let g:lognroll#enable_brackets = 0
" let g:lognroll#enable_insert_mode = 0

let g:indentLine_enabled = 1
let g:indentLine_char = '│'
let g:indentLine_color_gui = '#303034'
let g:indentLine_showFirstIndentLevel = 1

let g:db_ui_use_nerd_fonts = 1
let g:db_ui_show_database_icon = 1
let g:WebDevIconsNerdTreeBeforeGlyphPadding = ''
let g:WebDevIconsUnicodeDecorateFolderNodes = v:true
let g:NERDTreeDirArrowExpandable = " "
let g:NERDTreeDirArrowCollapsible = " "

let g:dbs = [
\ { 'name': 'prosapient_dev', 'url': 'postgres://postgres:postgres@localhost:5432/prosapient_dev' },
\ { 'name': 'prosapient_dev_byoe', 'url': 'postgres://postgres:postgres@localhost:5432/prosapient_dev_byoe' },
\ { 'name': 'prosapient_dev_mckinsey', 'url': 'postgres://postgres:postgres@localhost:5432/prosapient_dev_mckinsey' },
\ { 'name': 'prosapient_dev_outreach', 'url': 'postgres://postgres:postgres@localhost:5432/prosapient_dev_outreach' },
\ ]

call wilder#setup({'modes': [':']})

let g:NERDTreeMapOpenVSplit = 'v'
let g:NERDTreeMapOpenSplit = 's'
let g:DevIconsEnableFoldersOpenClose = 1

let g:NERDTreeWinSize=35

let NERDTreeMinimalUI=1

augroup nerdtreehidecwd
  autocmd!
  autocmd FileType nerdtree setlocal conceallevel=3
          \ | syntax match NERDTreeHideCWD #^[</].*$# conceal
          \ | setlocal concealcursor=n
augroup end

let g:airline#extensions#whitespace#mixed_indent_algo = 1

" Close the tab if NERDTree is the only window remaining in it.
autocmd BufEnter * if winnr('$') == 1 && exists('b:NERDTree') && b:NERDTree.isTabTree() | quit | endif

function! FoldSignColumnToggle()
    if &signcolumn == 'yes'
        set signcolumn=number
    else
        set signcolumn=yes
    endif
endfunction

nmap <silent> C :call FoldSignColumnToggle()<CR>

let g:db_ui_force_echo_notifications = 1

let g:EasyMotion_prompt = 'fast search as fuck:'
let g:EasyMotion_move_highlight = 0

set whichwrap+=<,h
let g:indent_blankline_show_first_indent_level = v:false
let g:matchup_matchparen_offscreen = { }


