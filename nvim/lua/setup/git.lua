local vimp = require("vimp")
local branch = vim.fn["gitbranch#name"]()

-- Git windows shortcuts
vimp.nnoremap("<leader>gcm", ":Git commit -v -q <CR>")
vimp.nnoremap("<leader>gd", ":Git diff")
vimp.nnoremap("<leader>gcl", ":Gclog -50<CR>")
vimp.nnoremap("<leader>gl", ":Git log -50<CR>")
vimp.nnoremap("<leader>gco", ":!fbr<CR>")
vimp.nnoremap("<C-g>", ":GFiles?<cr>")
vimp.nnoremap({ "chord", "silent" }, "<leader>g", ":Git<cr>")
vimp.nnoremap({ "silent" }, "<leader>G", ":Git<cr>")

-- Git push/pull/fetch shortcuts
vimp.nnoremap({"chord"}, "<Leader>gbp", ":Git push origin " .. branch .. "<CR>")
vimp.nnoremap("<Leader>gpf", ":Git push origin --force " .. branch .. "<CR>")
vimp.nnoremap("<Leader>gpl", ":Git pull origin " .. branch .. "<CR>")
vimp.nnoremap("<Leader>gfa", ":Git fetch --all<CR>")

-- Git rebase/blame/checkout/reset shortcuts
vimp.nnoremap('<Leader>grc', ':Git rebase --continue<CR>')
vimp.nnoremap('<Leader>gra', ':Git rebase --abort')
vimp.nnoremap('<Leader>grsh', ':Git reset --hard')
vimp.nnoremap('<Leader>gri', ':Git rebase --interactive HEAD~')
vimp.nnoremap('<Leader>gcb', ':Git checkout -b')
vimp.nnoremap('<Leader>gbl', ':Git blame -et<CR>')

-- Disable the default highlight group
vim.g.conflict_marker_highlight_group = ''

-- Include text after begin and end markers
vim.g.conflict_marker_begin = '^<<<<<<< .*$' 
vim.g.conflict_marker_common_ancestors = '^||||||| .*$'
vim.g.conflict_marker_separator = '^=======$'
vim.g.conflict_marker_end   = '^>>>>>>> .*$'

