local vimp = require("vimp")
local hop = require("hop")

hop.setup({
	create_hl_autocmd = false,
	extend_visual = true,
})

-- Return to normal mode
vimp.inoremap("jj", "<Esc>")

-- Fast search by character
vimp.noremap("S", hop.hint_char2)
vimp.nnoremap("s", hop.hint_char1)
vimp.vnoremap("s", hop.hint_char1)

-- Fast search by word
vimp.nnoremap({ "silent" }, "/", "<Plug>(easymotion-sn)")

-- Copy path
vimp.noremap("cp", ":CopyPath<CR>")

-- Untitled file
vimp.noremap("<leader>u", ":e untitled.txt")

-- Save on CTRL + S
vimp.nnoremap({ "silent" }, "<C-S>", ":w!<CR>")
vimp.vnoremap({ "silent" }, "<C-S>", "<Esc>:w!<CR>")
vimp.inoremap({ "silent" }, "<C-S>", "<Esc>:w!<CR>")

-- Fast exit from buffer
vimp.nmap("<Leader>q", ":bd!<cr>")

-- Clear highlighting on escape in normal mode
vimp.nnoremap("<Esc>", ":noh<cr><esc>")
vimp.nnoremap({ "silent" }, "<leader>tn", ":vnew %<cr>")

-- Copy to buffer on delete / paste / yank
vimp.xnoremap("p", '"_dP')
vimp.noremap("<leader>y", '"*y')
vimp.noremap("<leader>Y", '"*y$')
vimp.noremap("<leader>x", '"*x')
vimp.noremap("<leader>dd", '"*dd')
vimp.noremap("<leader>D", '"*D')

-- Comment lines
vimp.map({ "chord" }, "gc", "<Plug>Commentary")
vimp.nmap("gcc", "<Plug>CommentaryLine")

-- Marks
vimp.map("<leader>dm", ":delmarks A-Za-z0-9<cr>")
vimp.map("<leader>ms", ":DoShowMarks!<cr>")

vim.g.coc_default_semantic_highlight_groups = 1
