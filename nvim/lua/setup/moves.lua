local vimp = require("vimp")

-- Accelerated move
vim.g.accelerated_jk_acceleration_limit = 500

vimp.nmap("j", "<Plug>(accelerated_jk_gj)")
vimp.nmap("k", "<Plug>(accelerated_jk_gk)")

vim.g.accelerated_jk_acceleration_table = {30, 60, 90}

vim.g.comfortable_motion_no_default_key_mappings = 1

vimp.nmap({"silent"}, "C-u", ':lua require("neoscroll").scroll(-25, true, 200)<CR>')
vimp.nmap({"silent"}, "C-d", ':lua require("neoscroll").scroll(25, true, 200)<CR>')
vimp.nmap({"silent"}, "zt", ':lua require("neoscroll").zb(250)<CR>')
vimp.nmap({"silent"}, "zb", ':lua require("neoscroll").zt(250)<CR>')

-- Disable Arrow keys in Normal mode
vimp.map("<up>", "<nop>")
vimp.map("<down>", "<nop>")
vimp.map("<left>", "<nop>")
vimp.map("<right>", "<nop>")

-- Disable Arrow keys in Insert mode
vimp.imap("<up>", "<nop>")
vimp.imap("<down>", "<nop>")
vimp.imap("<left>", "<nop>")
vimp.imap("<right>", "<nop>")

-- Move lines by alt + arrows
vimp.nnoremap("∆", ":m .+1<CR>==")
vimp.nnoremap("˚", ":m .-2<CR>==")
vimp.inoremap("∆", "<Esc>:m .+1<CR>==gi")
vimp.inoremap("˚", "<Esc>:m .-2<CR>==gi")
vimp.vnoremap("∆", ":m '>+1<CR>gv-gv")
vimp.vnoremap("˚", ":m '<-2<CR>gv-gv")
