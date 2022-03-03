filetype plugin on

set mouse=a
set encoding=UTF-8

syntax on

au ColorScheme * hi Normal ctermbg=none guibg=none

colorscheme nvcode " colorscheme

augroup colorscheme_coc_setup | au!
	au ColorScheme * call s:my_colors_setup()
augroup END


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


if !has('nvim')
  set autoread
  set backspace=indent,eol,start " enable Backspace in insert mode
  set history=10000 " remember more commands and search history
  set nocompatible
endif

set t_Co=256
set number
" set termguicolors
set noswapfile

set lazyredraw            " improve scrolling performance when navigating through large results
set regexpengine=1        " use old regexp engine
set ignorecase smartcase  " ignore case only when the pattern contains no capital letters

let mapleader = " " " leader key

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
set scrolloff=10 " minimal lines around the cursor
set shiftwidth=0
set tabstop=2

let g:lognroll#enable_brackets = 0
let g:lognroll#enable_insert_mode = 0

let g:indentLine_char = '│'
let g:indentLine_color_gui = '#303034'
