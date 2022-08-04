local vimp = require("vimp")

require("fzf-lua").setup({ winopts = { height=0.9, width=0.94 } })

vimp.nmap({ "silent" }, "<C-f>", ":FzfLua files<CR>")
vimp.nmap({ "silent" }, "<C-p>", ":FzfLua live_grep<CR>")

