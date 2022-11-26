local opt = vim.opt

opt.splitright = true
opt.splitbelow = true

opt.re = 0

opt.signcolumn = "yes"
opt.cmdheight = 1
opt.updatetime = 200
opt.shortmess = "c"
opt.pumheight = 8
opt.textwidth = 75

opt.encoding = "utf-8"
opt.mouse = "a"
opt.cursorline = true -- highlight current line
opt.ruler = true -- show the cursor position

opt.shortmess = "atI" -- don't show the intro message when starting Vim
opt.indentexpr = ""
opt.showmatch = true -- highlight matching [{()}] "
opt.showmode = true --show the current mode
opt.hidden = true -- allow unsaved background buffers and remember marks/undo for them
opt.scrolloff = 11 -- minimal lines around the cursor

opt.number = true
opt.lazyredraw = true -- improve scrolling performance when navigating through large results

opt.ignorecase = true -- ignore case only when the pattern contains no capital letters

opt.timeout = true
opt.timeoutlen = 500
opt.ttimeoutlen = 100

opt.complete = ".,w,b,u,t,i,kspell"
opt.completeopt = "menu,menuone,noselect"
opt.whichwrap = "<,h"

opt.background = "light" -- colorscheme

opt.foldenable = true -- dont fold by default
opt.foldmethod = "indent" -- fold based on spaces
opt.foldlevelstart = 10 -- open most folds by default
opt.foldnestmax = 10 -- 10 nested fold max

opt.tabstop = 2 -- read as
opt.softtabstop = 2 -- insert as
opt.expandtab = true -- tabs are spaces
opt.smartindent = true
opt.shiftwidth = 2
opt.autoindent = true

opt.numberwidth = 4

opt.fillchars = {
    vert = "│",
    fold = "⠀",
    eob = " ", -- suppress ~ at EndOfBuffer
    msgsep = " ",
    foldopen = "▾",
    foldsep = " ",
    foldclose = "▸"
}

opt.termguicolors = true

vim.cmd(
    [[
filetype plugin on
syntax on

colorscheme solarized8_flat

" hi EndOfBuffer guifg=#fdf6e3
hi MatchParen guifg=NONE gui=underline cterm=underline ctermbg=66 guifg=white guibg=#b3b3b3
hi VertSplit guibg=NONE guifg=#b3b3b3
autocmd FileType * set formatoptions+=t

" hi ConflictMarkerBegin guibg=#e6cd85 guifg=#FFFFFF
" hi ConflictMarkerOurs guibg=#FAEFD1
" hi ConflictMarkerTheirs guibg=#DDEFFA
" hi ConflictMarkerEnd guibg=#F5DDDC guifg=NONE 
" hi ConflictMarkerSeparator guibg=NONE guifg=NONE 
" hi ConflictMarkerCommonAncestorsHunk guibg=NONE
" hi ConflictMarkerCommonAncestors guibg=NONE

hi BufferLineFill ctermbg=254 guibg=#eee8d5
hi BufferLineBufferSelected gui=bold cterm=bold
highlight IndentBlanklineChar guifg=#8b9898 gui=nocombine guibg=NONE
hi typescriptParens guifg=#6d8086
hi DevIconJs guifg=orange 
hi DevIconEnv guifg=orange 
hi IndentBlanklineChar guifg=#b3b3b3

" hi MsgArea guifg=#657b83 guibg=#eee8d5
" hi NvimTreeNormal guifg=#657b83 guibg=#eee8d

hi DiagnosticUnderlineWarn gui=undercurl cterm=undercurl
hi DiagnosticUnderlineHint gui=undercurl cterm=undercurl
hi DiagnosticUnderlineError gui=undercurl cterm=undercurl
hi DiagnosticUnderlineInfo gui=undercurl cterm=undercurl
hi DiagnosticUnderlineHint gui=undercurl cterm=undercurl

hi Error cterm=NONE gui=NONE guifg=NONE ctermbg=NONE

hi CmpItemAbbrMatch guifg=#cb4b16
hi GitSignsCurrentLineBlame gui=italic

function! s:GotoFirstFloat() abort
  for w in range(1, winnr('$'))
    let c = nvim_win_get_config(win_getid(w))
    if c.focusable && !empty(c.relative)
      execute w . 'wincmd w'
    endif
  endfor
endfunction
noremap <c-w><space> :<c-u>call <sid>GotoFirstFloat()<cr>
]]
)

vim.g.mapleader = " "

vim.g["far#enable_undo"] = 1

vim.g.solarized_visibility = "high"
vim.g.solarized_extra_hi_groups = 1

vim.g.db_ui_use_nerd_fonts = 1
vim.g.db_ui_show_database_icon = 1

vim.g.db_ui_force_echo_notifications = 0

vim.g.matchup_matchparen_offscreen = {}

vim.g.db_ui_win_position = "right"
vim.g.db_ui_save_location = "~/.config/db_ui/queries"

vim.g.dbs = {
    dev = {name = "prosapient_dev", url = "postgres://postgres:postgres@localhost:5432/prosapient_dev"},
    byoe = {name = "prosapient_dev_byoe", url = "postgres://postgres:postgres@localhost:5432/prosapient_dev_byoe"},
    aggregator = {
        name = "prosapient_dev_aggregator",
        url = "postgres://postgres:postgres@localhost:5432/prosapient_dev_aggregator"
    },
    lek = {name = "prosapient_dev_lek", url = "postgres://postgres:postgres@localhost:5432/prosapient_dev_lek"},
    mckinsey = {
        name = "prosapient_dev_mckinsey",
        url = "postgres://postgres:postgres@localhost:5432/prosapient_dev_mckinsey"
    },
    outreach = {
        name = "prosapient_dev_outreach",
        url = "postgres://postgres:postgres@localhost:5432/prosapient_dev_outreach"
    }
}

for _, keymap in pairs(
    {
        "zo",
        "zO",
        "zc",
        "zC",
        "za",
        "zA",
        "zv",
        "zx",
        "zX",
        "zm",
        "zM",
        "zr",
        "zR"
    }
) do
    vim.api.nvim_set_keymap("n", keymap, keymap .. "<CMD>IndentBlanklineRefresh<CR>", {noremap = true, silent = true})
end

vim.g.delimitMate_matchpairs = "(:),[:],{:}"
vim.g.delimitMate_expand_space = 1
vim.g.delimitMate_balance_matchpairs = 1
vim.g.delimitMate_expand_cr = 1
