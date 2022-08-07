local vimp = require("vimp")

vimp.nnoremap("<leader>v", ":vnew %<cr>")
vimp.nnoremap("<leader>s", ":new %<cr>")
vimp.nnoremap("<leader>ev", ":vnew %<cr>")
vimp.nnoremap("<leader>es", ":new %<cr>")

vimp.nmap("<leader>l", ":bn<cr>")
vimp.nmap("<leader>h", ":bp<cr>")
